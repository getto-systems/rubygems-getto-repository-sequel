require "getto/initialize_with"

require "getto/repository/page"

require "nkf"

module Getto
  module Repository
    # :nocov:
    class Sequel
      class Search
        include Getto::InitializeWith

        initialize_with :limit, :sort, :query

        def pages(count)
          Getto::Repository::Page.new(count: count, limit: limit).pages
        end

        def where
          where = []
          yield Where.new(query: query, where: where)

          where.compact!

          if where.empty?
            {1 => 1}
          else
            ::Sequel.&(*where)
          end
        end

        def order
          order = []
          yield Order.new(sort: sort, order: order)
          order
        end

        class Where
          def cont(column)
            ->(value){ ::Sequel.like(column, "%#{value}%") }
          end

          def cont_hira_or_kana(column)
            self.or([
              cont_as_kana(column),
              cont_as_hira(column),
            ])
          end

          def cont_as_kana(column)
            ->(value){
              cont(column).call NKF.nkf("--katakana -w", value)
            }
          end

          def cont_as_hira(column)
            ->(value){
              cont(column).call NKF.nkf("--hiragana -w", value)
            }
          end

          def eq(column)
            ->(value){ { column => value } }
          end

          def gteq(column)
            ->(value){ ::Sequel.lit("? >= ?", column, value) }
          end

          def lteq(column)
            ->(value){ ::Sequel.lit("? <= ?", column, value) }
          end

          def is_not_null(column,map)
            ->(value){
              if map.has_key?(value)
                if map[value]
                  ::Sequel.~(column => nil)
                else
                  {column => nil}
                end
              end
            }
          end


          def in(&query)
            ->(value){
              where = value.map(&query).compact
              unless where.empty?
                ::Sequel.|(*where)
              end
            }
          end


          def or(wheres)
            wheres = wheres.compact

            ->(value){
              unless wheres.empty?
                ::Sequel.|(*wheres.map{|w| w.call(value)})
              end
            }
          end


          def initialize(query:, where:)
            @query = query
            @where = where
          end

          def search(column,&block)
            if @query.has_key?(column.to_sym)
              @where << block.call(@query[column.to_sym])
            end
          end
        end

        class Order
          def initialize(sort:, order:)
            @sort = sort
            @order = order
          end

          def order(key,column)
            if @sort[:column] == key
              force(column)
            end
          end

          def force(column)
            if @sort[:order]
              @order << ::Sequel.asc(column)
            else
              @order << ::Sequel.desc(column)
            end
          end

          def is_not_null(column, not_null_value, null_value)
            ::Sequel.function(
              :if,
              ::Sequel.lit("? is not null", column),
              not_null_value, null_value)
          end
        end

      end
    end
    # :nocov:
  end
end
