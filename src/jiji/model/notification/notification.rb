# frozen_string_literal: true

require 'jiji/configurations/mongoid_configuration'
require 'jiji/utils/value_object'
require 'jiji/errors/errors'
require 'jiji/web/transport/transportable'

module Jiji::Model::Notification
  class Notification

    DEFAULT_READ_AT = Time.at(0)

    include Mongoid::Document
    include Jiji::Utils::ValueObject
    include Jiji::Web::Transport::Transportable
    include Jiji::Errors

    store_in collection: 'notifications'
    belongs_to :agent, {
      class_name: 'Jiji::Model::Agents::AgentSetting'
    }
    belongs_to :backtest, {
      class_name: 'Jiji::Model::Trading::BackTestProperties',
      optional:   true
    }

    field :actions,       type: Array
    field :message,       type: String
    field :timestamp,     type: Time
    field :read_at,       type: Time, default: DEFAULT_READ_AT
    field :note,          type: String
    field :options,       type: Hash

    index(
      { backtest_id: 1, timestamp: -1 },
      name: 'notification_backtest_id_timestamp_index')

    def self.create(agent, timestamp,
      backtest = nil, message = '', actions = [], note = nil, options = nil)
      Notification.new do |n|
        n.timestamp = timestamp
        n.initialize_agent_information(agent, backtest)
        n.initialize_content(message, actions, note, options)
      end
    end

    def read(timestamp)
      self.read_at = timestamp
      save
    end

    def read?
      read_at != DEFAULT_READ_AT
    end

    def to_h
      hash = {
        id:        id,
        timestamp: timestamp,
        read_at:   read? ? read_at : nil
      }
      insert_content_to_hash(hash)
      insert_agent_information_to_hash(hash)
      hash
    end

    def initialize_agent_information(agent, backtest)
      self.agent    = agent
      self.backtest = backtest
    end

    def initialize_content(message = '',
      actions = [], note = nil, options = nil)
      self.message     = message
      self.actions     = actions
      self.note        = note
      self.options     = options
    end

    def title
      title = "#{agent.name} | #{backtest ? backtest.name : 'リアルトレード'}"
      title = title[0, 70] if title.length > 70
      title
    end

    def self.drop
      client = mongo_client
      client['notifications'].drop
    end

    private

    def insert_content_to_hash(hash)
      hash[:message] = message
      hash[:actions] = actions
      hash[:note]    = note
      hash[:options] = options
    end

    def insert_agent_information_to_hash(hash)
      hash[:backtest] = backtest ? backtest.display_info : {}
      hash[:agent]    = agent ? agent.display_info : {}
    end

  end
end
