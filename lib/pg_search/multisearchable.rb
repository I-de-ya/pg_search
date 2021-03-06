require "active_support/core_ext/class/attribute"

module PgSearch
  module Multisearchable
    def self.included(mod)
      mod.class_eval do
        has_one :pg_search_document,
          :as => :searchable,
          :class_name => "PgSearch::Document",
          :dependent => :delete

        after_save :update_pg_search_document,
          :if => -> { PgSearch.multisearch_enabled? }
      end
    end

    def searchable_text
      Array(pg_search_multisearchable_options[:against])
        .map { |symbol| send(symbol) }
        .join(" ")
    end

    def pg_search_document_attrs
      {
        content: searchable_text
      }.tap do |h|
        if (attrs = pg_search_multisearchable_options[:additional_attributes])
          h.merge! attrs.to_proc.call(self)
        end
      end
    end

    def update_pg_search_document # rubocop:disable Metrics/AbcSize
      if_conditions = Array(pg_search_multisearchable_options[:if])
      unless_conditions = Array(pg_search_multisearchable_options[:unless])

      should_have_document =
        if_conditions.all? { |condition| condition.to_proc.call(self) } &&
        unless_conditions.all? { |condition| !condition.to_proc.call(self) }

      if should_have_document
        attrs = pg_search_document_attrs
        attrs[:searchable_type] = self.class.name
        (pg_search_document || build_pg_search_document)
            .update(attrs)
      else
        pg_search_document.destroy if pg_search_document
      end
    end
  end
end
