# frozen_string_literal: true

require 'jiji/test/test_configuration'

require 'logger'

describe Jiji::Model::Logging::Log do
  include_context 'use backtests'
  let(:time_source) { Jiji::Utils::TimeSource.new }
  let(:log) { Jiji::Model::Logging::Log.new(time_source) }
  let(:backtest_log) do
    Jiji::Model::Logging::Log.new(time_source, backtests[0]._id)
  end
  let(:logger) { Logger.new(log) }
  let(:backtest_logger) { Logger.new(backtest_log) }

  it 'ログを保存できる' do
    time_source.set(Time.at(100))

    logger.warn('test')
    logger.error(StandardError.new('test'))

    expect(log.count).to be 1
    log_data = log.get(0)
    expect(log_data.size).to be > 0
    expect(log_data.timestamp).to eq Time.at(100)
    expect(log_data.body.length).to be > 0
    expect(log_data.to_h[:body]).not_to be nil
    puts log_data.to_h[:body]
  end

  it '100kを超えると、別のデータに分割される' do
    1001.times do |i|
      time_source.set(Time.at(i * 100))
      logger.info('x' * 1024)
    end

    expect(log.count).to be 11
    11.times do |i|
      log_data = log.get(i)
      expect(log_data.size).to be > 0
      expect(log_data.timestamp).not_to be nil
      expect(log_data.body.length).to be > 0
      expect(log_data.to_h[:body]).not_to be nil
    end
  end

  it 'Logを再作成した場合、新しいLogDataが作成される' do
    11.times do |i|
      time_source.set(Time.at(i * 10))
      logger.info('x' * 1024 * 20)
    end
    expect(log.count).to be 3

    time_source.set(Time.at(200))
    new_log = Jiji::Model::Logging::Log.new(time_source)
    new_logger = Logger.new(new_log)
    new_logger.warn('bbb')

    expect(log.count).to be 3
    expect(new_log.count).to be 3

    log_data = new_log.get(2)
    expect(log_data.size).to be > 0
    expect(log_data.timestamp).to eq Time.at(200)
    expect(log_data.body.length).to be 1

    log_data = new_log.get(1)
    expect(log_data.size).to be > 0
    expect(log_data.timestamp).to eq Time.at(40)
    expect(log_data.body.length).to be 5

    log_data = new_log.get(0)
    expect(log_data.size).to be > 0
    expect(log_data.timestamp).to eq Time.at(0)
    expect(log_data.body.length).to be 5
  end

  it 'close でバッファのデータが永続化される' do
    time_source.set(Time.at(0))
    logger.info('x' * 1024 * 2)
    logger.info('x' * 1024 * 2)

    log2 = Jiji::Model::Logging::Log.new(time_source)
    expect(log2.count).to be 0

    logger.close
    expect(log2.count).to be 1
    log_data = log2.get(0)
    expect(log_data.timestamp).to eq Time.at(0)
    expect(etract_log_content(log_data.body).length).to eq(1024 * 4)
  end

  describe '#get' do
    it '指定したインデックスのログデータを取得できる' do
      110.times do |i|
        time_source.set(Time.at(i * 10))
        logger.info('x' * 1024 * 2)
      end

      expect(log.count).to be 3
      log_data = log.get(0)
      expect(log_data.timestamp).to eq Time.at(0)
      expect(etract_log_content(log_data.body).length).to eq(1024 * 2 * 49)
      log_data = log.get(1)
      expect(log_data.timestamp).to eq Time.at(48 * 10)
      expect(etract_log_content(log_data.body).length).to eq(1024 * 2 * 49)
      log_data = log.get(2)
      expect(log_data.timestamp).to eq Time.at(97 * 10)
      expect(etract_log_content(log_data.body).length).to eq(1024 * 2 * 12)

      logger.close
      expect(log.count).to be 3
      log_data = log.get(0)
      expect(log_data.timestamp).to eq Time.at(0)
      expect(etract_log_content(log_data.body).length).to eq(1024 * 2 * 49)
      log_data = log.get(1)
      expect(log_data.timestamp).to eq Time.at(48 * 10)
      expect(etract_log_content(log_data.body).length).to eq(1024 * 2 * 49)
      log_data = log.get(2)
      expect(log_data.timestamp).to eq Time.at(97 * 10)
      expect(etract_log_content(log_data.body).length).to eq(1024 * 2 * 12)
    end

    it '不正なindexを指定した場合、nullが返される' do
      expect(log.get(0)).to be nil
      expect(log.get(1)).to be nil
    end
  end

  it '別のLogが管理するデータとは影響し合わない' do
    time_source.set(Time.at(100))

    logger.warn('test')
    logger.error(StandardError.new('test'))
    logger.close

    backtest_logger.warn('test')
    backtest_logger.error(StandardError.new('test'))
    backtest_logger.close

    expect(log.count).to be 1
    log_data = log.get(0)
    expect(log_data.size).to be > 0

    expect(backtest_log.count).to be 1
    log_data = backtest_log.get(0)
    expect(log_data.size).to be > 0
  end

  def etract_log_content(body)
    body.map { |l| l.split(' -- : ')[1].chop }.join('')
  end
end
