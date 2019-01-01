# coding: utf-8

require 'jiji/test/data_builder'

module Jiji::Test::Mock
  class MockSecurities < Jiji::Model::Securities::VirtualSecurities

    include Jiji::Errors
    include Jiji::Model::Trading
    include Jiji::Model::Securities::Internal::Virtual

    attr_reader :config
    attr_writer :pairs
    attr_accessor :seed, :positions, :orders, :balance, :i, :seeds

    def initialize(config)
      @position_builder = Internal::PositionBuilder.new

      init_ordering_state(config[:orders] || [])
      init_trading_state(config[:positions] || [])

      @config = config
      @serial = 0
      @i = -1
      @seeds = [0, 0.26, 0.3, 0.303, 0.301, 0.4, 0.401, 0.35, 0.36, 0.2, 0.1]

      @data_builder = Jiji::Test::DataBuilder.new
      @order_validator = OrderValidator.new
      @balance = config[:balance] || 100_000
      retrieve_account
    end

    def reset
      @i = -1
      @serial = 0
    end

    def destroy
    end

    def retrieve_pairs
      @pairs ||= [
        Pair.new(:EURJPY, 'EUR_JPY', 0.01,   10_000_000, 0.001,   0.04),
        Pair.new(:EURUSD, 'EUR_USD', 0.0001, 10_000_000, 0.00001, 0.04),
        Pair.new(:USDJPY, 'USD_JPY', 0.01,   10_000_000, 0.001,   0.04)
      ]
    end

    def retrieve_current_tick
      @current_tick = create_tick(
        @seeds[(@i += 1) % @seeds.length],
        Time.utc(2015, 5, 1) + @i * 15)
      update_orders(@current_tick)
      update_positions(@current_tick)
      @current_tick
    end

    def retrieve_tick_history(pair_name,
      start_time, end_time, interval_id = nil)
      interval = interval_id.nil? \
        ? 15 : Intervals.instance.get(interval_id).ms / 1000
      i = -1
      create_timestamps(interval, start_time, end_time).map do |time|
        create_tick(@seeds[(i += 1) % @seeds.length], time)
      end
    end

    def retrieve_rate_history(pair_name, interval, start_time, end_time)
      if pair_name != :EURJPY && pair_name != :EURUSD && pair_name != :USDJPY
        not_found
      end
      interval_ms = Jiji::Model::Trading::Intervals.instance \
        .resolve_collecting_interval(interval)
      create_timestamps(interval_ms / 1000, start_time, end_time).map do |time|
        Rate.new(pair_name, time,
          create_tick_value(112,    112.04),
          create_tick_value(112.10, 112.14),
          create_tick_value(113.10, 113.14),
          create_tick_value(111.10, 111.14))
      end
    end

    def self.register_securities_to(factory)
      factory.register_securities(:MOCK,  'モック',  [], self)
      factory.register_securities(:MOCK2, 'モック2', [], MockSecurities2)
    end

    def retrieve_account
      raise 'test' if @config['fail_on_test_connection']
      account = Account.new(0, 'JPY', @balance, 0.04)
      account.update(@positions, @current_tick ? @current_tick.timestamp : nil)
      account
    end

    def account_currency
      'JPY'
    end

    def close_trade(internal_id)
      position = find_position_by_internal_id(internal_id)
      @balance += position.profit_or_loss
      super(internal_id)
    end

    def retrieve_calendar(period, pair_name = nil)
      return CALENDAR_INFORMATIONS unless pair_name
      if pair_name =~ /USD/
        CALENDAR_INFORMATIONS.reject { |i| i.currency != 'USD' }
      elsif pair_name =~ /JPY/
        CALENDAR_INFORMATIONS.reject { |i| i.currency != 'JPY' }
      else
        []
      end
    end

    CalndarInformationSrc = Struct.new(:title, :timestamp, :unit,
      :currency, :forecast, :previous, :actual, :market, :region, :impact)
    CALENDAR_INFORMATIONS = [
      EconomicCalendarInformation.new(
        CalndarInformationSrc.new(
          'Non-farm Payrolls', 1000, 'k', 'USD', '225', '245', '215',
          '205', 'americas', 3
        )
      ),
      EconomicCalendarInformation.new(
        CalndarInformationSrc.new(
          'Univ of Mich Sent. (Final)', 2000, 'index', 'USD', '91',
          '90', '91.0', '90.5', 'americas', 2
        )
      ),
      EconomicCalendarInformation.new(
        CalndarInformationSrc.new(
          'ISM Manufacturing', 3000, 'index', 'JPY', '51', '49.5',
          '51.8', '51', 'asia', 3
        )
      )
    ].freeze

    private

    def create_timestamps(interval, start_time, end_time)
      start_time.to_i.step(end_time.to_i - 1, interval).map { |t| Time.at(t) }
    end

    def create_tick(seed, time = Time.utc(2015, 5, 1) + seed * 1000)
      Tick.new({
        EURUSD: create_tick_value(1.1234, 1.1236, seed),
        USDJPY: create_tick_value(112.10, 112.12, seed),
        EURJPY: create_tick_value(135.30, 135.33, seed)
      }, time)
    end

    def create_tick_value(bid, ask, seed = 0)
      Tick::Value.new(
        (BigDecimal(bid, 10) + seed).to_f,
        (BigDecimal(ask, 10) + seed).to_f)
    end

  end

  class MockSecurities2 < MockSecurities

  end
end
