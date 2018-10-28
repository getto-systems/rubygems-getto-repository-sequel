module Getto
  module Repository
    # :nocov:
    class Sequel
      def initialize(db)
        @db = db
      end

      attr_reader :db

      def transaction
        db.transaction do
          yield
        end
      end

      def last_insert_id
        db["select last_insert_id() as id"]
          .map{|hash| hash[:id]}.first
      end
    end
    # :nocov:
  end
end
