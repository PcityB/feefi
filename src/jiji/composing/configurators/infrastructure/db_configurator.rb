# frozen_string_literal: true

module Jiji::Composing::Configurators
  class DBConfigurator < AbstractConfigurator

    include Jiji::Db

    def configure(container)
      container.configure do
        object :index_builder, IndexBuilder.new
      end

      configure_migration_components(container)
    end

    private

    def configure_migration_components(container)
      container.configure do
        object :migrator, Migrator.new

        object :v0to1_register_system_agents, RegisterSystemAgents.new
        object :v0to1_register_builtin_icons, RegisterBuiltinIcons.new
        object :v0to1_create_capped_collections, CreateCappedCollections.new({
          notifications: { size: 20 * 1024 * 1024 },
          log_data:      { size: 50 * 1024 * 1024 }
        })
      end
    end

  end
end
