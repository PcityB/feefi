# frozen_string_literal: true

module Jiji::Model::Trading::Jobs
  class Job

    attr_reader :future

    def initialize
      @future = Jiji::Utils::Future.new
    end

    def exec(context, queue)
      @future.value = call(context, queue)
    rescue StandardError => e
      @future.error = e
      raise e
    end

    def call(_context, queue); end

    def self.create_from(&block)
      ProcJob.new(&block)
    end

  end

  class ProcJob < Job

    def initialize(&block)
      super()
      @block = block
    end

    def call(trading_context, queue)
      @block.call(trading_context, queue)
    end

  end
end
