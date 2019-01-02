# frozen_string_literal: true

require 'jiji/test/test_configuration'

describe Jiji::Model::Trading::RMT do
  include_context 'use data_builder'

  before(:example) do
    @container    = Jiji::Test::TestContainerFactory.instance.new_container
    @rmt          = @container.lookup(:rmt)
    @time_source  = @container.lookup(:time_source)
    @settings     = @container.lookup(:setting_repository)
    @registory    = @container.lookup(:agent_registry)

    @registory.add_source('aaa', '', :agent, data_builder.new_agent_body(1))
    @registory.add_source('bbb', '', :agent, data_builder.new_agent_body(2))
  end

  after(:example) do
    @rmt.tear_down
  end

  it 'エージェントを追加/更新できる' do
    @rmt.setup
    agent_setting = @settings.rmt_setting.agent_setting
    expect(agent_setting.length).to eq 0

    agent_setting = @rmt.update_agent_setting([
      {
        agent_class: 'TestAgent1@aaa',
        agent_name:  'テスト1',
        properties:  { 'a' => 100, 'b' => 'bb' }
      }, {
        agent_class: 'TestAgent1@aaa',
        agent_name:  'テスト2',
        properties:  {}
      }, {
        agent_class: 'TestAgent2@bbb'
      }
    ]).map { |x| x }
    expect(agent_setting[0].id).not_to be nil
    expect(agent_setting[0].agent_class).to eq 'TestAgent2@bbb'
    expect(agent_setting[0].name).to eq nil
    expect(agent_setting[0].properties).to eq({})
    agent = @rmt.agents[agent_setting[0].id]
    expect(agent.agent_name).to eq 'TestAgent2@bbb'
    expect(agent.broker.agent.id).to eq agent_setting[0].id

    expect(agent_setting[1].id).not_to be nil
    expect(agent_setting[1].agent_class).to eq 'TestAgent1@aaa'
    expect(agent_setting[1].name).to eq 'テスト1'
    expect(agent_setting[1].properties).to eq({ 'a' => 100, 'b' => 'bb' })
    agent = @rmt.agents[agent_setting[1].id]
    expect(agent.agent_name).to eq 'テスト1'
    expect(agent.broker.agent.id).to eq agent_setting[1].id

    expect(agent_setting[2].id).not_to be nil
    expect(agent_setting[2].agent_class).to eq 'TestAgent1@aaa'
    expect(agent_setting[2].name).to eq 'テスト2'
    expect(agent_setting[2].properties).to eq({})
    agent = @rmt.agents[agent_setting[2].id]
    expect(agent.agent_name).to eq 'テスト2'
    expect(agent.broker.agent.id).to eq agent_setting[2].id

    new_setting = [{
      id:          agent_setting[1].id,
      agent_class: 'TestAgent1@aaa',
      agent_name:  'テスト3',
      properties:  { 'a' => 200, 'b' => 'bb' }
    }]
    new_agent_setting = @rmt.update_agent_setting(new_setting).map { |x| x }
    expect(new_agent_setting[0].id).to eq agent_setting[1].id
    expect(@rmt.agents[agent_setting[1].id]).not_to be nil
    expect(@rmt.agents[agent_setting[0].id]).to be nil
    expect(@rmt.agents[agent_setting[2].id]).to be nil

    expect(new_agent_setting[0].id).not_to be nil
    expect(new_agent_setting[0].agent_class).to eq 'TestAgent1@aaa'
    expect(new_agent_setting[0].name).to eq 'テスト3'
    expect(new_agent_setting[0].properties).to eq({ 'a' => 200, 'b' => 'bb' })
    agent = @rmt.agents[new_agent_setting[0].id]
    expect(agent.agent_name).to eq 'テスト3'
    expect(agent.broker.agent.id).to eq new_agent_setting[0].id
  end

  it '永続化したデータから状態を復元できる' do
    @rmt.setup
    agent_setting = @rmt.update_agent_setting([
      {
        agent_class: 'TestAgent1@aaa',
        agent_name:  'テスト1',
        properties:  { 'a' => 100, 'b' => 'bb' }
      }, {
        agent_class: 'TestAgent1@aaa',
        agent_name:  'テスト2',
        properties:  {}
      }, {
        agent_class: 'TestAgent2@bbb'
      }
    ]).map { |x| x }
    @rmt.tear_down

    @container    = Jiji::Test::TestContainerFactory.instance.new_container
    @rmt          = @container.lookup(:rmt)
    @settings     = @container.lookup(:setting_repository)
    @rmt.setup

    expect(agent_setting[0].id).not_to be nil
    expect(agent_setting[0].agent_class).to eq 'TestAgent2@bbb'
    expect(agent_setting[0].name).to eq nil
    expect(agent_setting[0].properties).to eq({})
    agent = @rmt.agents[agent_setting[0].id]
    expect(agent.agent_name).to eq 'TestAgent2@bbb'
    expect(agent.broker.agent.id).to eq agent_setting[0].id

    expect(agent_setting[1].id).not_to be nil
    expect(agent_setting[1].agent_class).to eq 'TestAgent1@aaa'
    expect(agent_setting[1].name).to eq 'テスト1'
    expect(agent_setting[1].properties).to eq({ 'a' => 100, 'b' => 'bb' })
    agent = @rmt.agents[agent_setting[1].id]
    expect(agent.agent_name).to eq 'テスト1'
    expect(agent.broker.agent.id).to eq agent_setting[1].id

    expect(agent_setting[2].id).not_to be nil
    expect(agent_setting[2].agent_class).to eq 'TestAgent1@aaa'
    expect(agent_setting[2].name).to eq 'テスト2'
    expect(agent_setting[2].properties).to eq({})
    agent = @rmt.agents[agent_setting[2].id]
    expect(agent.agent_name).to eq 'テスト2'
    expect(agent.broker.agent.id).to eq agent_setting[2].id
  end

  describe 'balance_of_yesterday' do
    it 'データが未登録の場合、nil' do
      @rmt.setup
      @time_source.set(Time.local(2015, 5, 1, 6, 0, 0))

      expect(@rmt.balance_of_yesterday).to be nil
    end
    it 'one_dayのデータから昨日の最新のデータが取得され、返却される' do
      @rmt.setup
      @rmt.stop_next_tick_job_generator

      graph = nil
      @rmt.process.post_exec do
        graph = @rmt.trading_context.graph_factory.create_balance_graph
        start_time = Time.local(2015, 5, 1, 18, 0, 0)
        15.times do |i|
          graph << [1000 * i]
          graph.save_data(start_time + (i * 60 * 60 * 6))
        end
      end.value

      start_time = Time.local(2015, 5, 1, 0, 0, 0)
      end_time   = Time.local(2015, 5, 6, 0, 0, 0)
      expect(graph.fetch_data(start_time, end_time).length).to be >= 14
      expect(graph.fetch_data(start_time, end_time, :one_day).length).to eq 5

      @time_source.set(Time.local(2015, 5, 1, 0, 0, 0))
      expect(@rmt.balance_of_yesterday).to be nil
      @time_source.set(Time.local(2015, 5, 1, 8, 59, 0))
      expect(@rmt.balance_of_yesterday).to be nil
      @time_source.set(Time.local(2015, 5, 1, 9, 0, 0))
      expect(@rmt.balance_of_yesterday).to be nil
      @time_source.set(Time.local(2015, 5, 1, 23, 59, 59))
      expect(@rmt.balance_of_yesterday).to be nil
      @time_source.set(Time.local(2015, 5, 2, 0, 0, 0))
      expect(@rmt.balance_of_yesterday).to eq 0
      @time_source.set(Time.local(2015, 5, 2, 8, 59, 0))
      expect(@rmt.balance_of_yesterday).to eq 0
      @time_source.set(Time.local(2015, 5, 2, 9, 0, 0))
      expect(@rmt.balance_of_yesterday).to eq 0
      @time_source.set(Time.local(2015, 5, 2, 23, 59, 59))
      expect(@rmt.balance_of_yesterday).to eq 0
      @time_source.set(Time.local(2015, 5, 3, 3, 0, 0))
      expect(@rmt.balance_of_yesterday).to eq 4000
      @time_source.set(Time.local(2015, 5, 4, 4, 0, 0))
      expect(@rmt.balance_of_yesterday).to eq 8000
      @time_source.set(Time.local(2015, 5, 5, 5, 0, 0))
      expect(@rmt.balance_of_yesterday).to eq 12_000
      @time_source.set(Time.local(2015, 5, 6, 6, 0, 0))
      expect(@rmt.balance_of_yesterday).to eq 14_000
      @time_source.set(Time.local(2015, 5, 7, 7, 0, 0))
      expect(@rmt.balance_of_yesterday).to be nil
    end
  end
end
