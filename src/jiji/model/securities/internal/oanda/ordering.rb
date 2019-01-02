# frozen_string_literal: true

require 'oanda_api'
require 'jiji/model/securities/internal/oanda/converter'

module Jiji::Model::Securities::Internal::Oanda
  module Ordering
    include Jiji::Errors
    include Jiji::Model::Trading

    def order(pair_name, sell_or_buy, units, type = :market, options = {})
      convert_expiry_date(options)
      response = @client.account(@account.account_id).order({
          instrument: Converter.convert_pair_name_to_instrument(pair_name),
          type:       type.to_s,
          side:       sell_or_buy.to_s,
          units:      units
      }.merge(options)).create
      convert_response_to_order_result(response, type)
    end

    def retrieve_orders(count = 500, pair_name = nil, max_id = nil)
      param = { count: count }
      if pair_name
        param[:instrument] =
          Converter.convert_pair_name_to_instrument(pair_name)
      end
      param[:max_id] = max_id if max_id
      @client.account(@account.account_id)
        .orders(param).get.map do |item|
        convert_response_to_order(item, item)
      end
    end

    def retrieve_order_by_id(internal_id)
      response = @client.account(@account.account_id)
        .order(internal_id).get
      convert_response_to_order(response, response)
    end

    def modify_order(internal_id, options = {})
      convert_expiry_date(options)
      response = @client.account(@account.account_id)
        .order({ id: internal_id }.merge(options)).update
      convert_response_to_order(response, response)
    end

    def cancel_order(internal_id)
      response = @client.account(@account.account_id)
        .order(internal_id).close
      convert_response_to_order(response, response)
    end

    private

    def convert_expiry_date(options)
      return unless options[:expiry]

      if options[:expiry].is_a?(Time)
        options[:expiry] = options[:expiry].utc.to_datetime.rfc3339
      end
    end

    def convert_response_to_order_result(res, type)
      args = %i[order_opened trade_opened].map do |m|
        value = res.method(m).call
        value.id ? convert_response_to_order(res, value, type) : nil
      end
      args << convert_response_to_reduced_position(res, res.trade_reduced)
      args << res.trades_closed.map do |r|
        convert_response_to_closed_position(res, r)
      end
      OrderResult.new(*args)
    end

    def convert_response_to_order(item, detail, type = nil)
      pair_name = Converter.convert_instrument_to_pair_name(item.instrument)
      t = type || detail.type.to_sym
      order = Order.new(pair_name, detail.id.to_s,
        detail.side.to_sym, t, item.time)
      order.price = item.price
      copy_options(order, detail, t)
      order
    end

    def convert_response_to_reduced_position(item, detail)
      if detail.id
        # trade_reducedからは損益は取得できない。ローカルで計算した近似値を使う
        ReducedPosition.new(detail.id.to_s,
          detail.units, item.price, item.time, nil)
      end
    end

    def convert_response_to_closed_position(item, detail)
      # trade_closedからは損益は取得できない。ローカルで計算した近似値を使う
      ClosedPosition.new(detail[:id].to_s,
        detail[:units].to_i, item.price, item.time, nil)
    end

    def copy_options(order, detail, type)
      order.units         = detail.units
      order.stop_loss     = detail.stop_loss
      order.take_profit   = detail.take_profit
      order.trailing_stop = detail.trailing_stop

      copy_reservation_order_options(order, detail) unless type == :market
    end

    def copy_reservation_order_options(order, detail)
      order.expiry        = detail.expiry
      order.lower_bound   = detail.lower_bound
      order.upper_bound   = detail.upper_bound
    end
  end
end
