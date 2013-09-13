# Copyright (C) 2013  Kouhei Sutou <kou@clear-code.com>
# Copyright (C) 2013  Kosuke Asami
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "groonga/client/response/base"

module Groonga
  class Client
    module Response
      class Select < Base
        Response.register("select", self)

        attr_accessor :records, :n_records
        attr_accessor :drilldowns

        def initialize(header, body)
          super(header, parse_body(body))
        end

        private
        def parse_body(body)
          @n_records, @records = parse_match_records(body.first)
          @drilldowns = parse_drilldowns(body[1..-1])
          body
        end

        def parse_result(raw_result)
          n_items = raw_result.first.first
          properties = raw_result[1]
          infos = raw_result[2..-1]
          items = infos.collect do |info|
            item = {}
            properties.each_with_index do |(name, type), i|
              item[name] = convert_value(info[i], type)
            end
            item
          end if infos
          [n_items, items]
        end

        def convert_value(value, type)
          case type
          when "Time"
            Time.at(value)
          else
            value
          end
        end

        def parse_match_records(raw_records)
          parse_result(raw_records)
        end

        def parse_drilldowns(raw_drilldowns)
          raw_drilldowns.collect do |raw_drilldown|
            n_hits, items = parse_result(raw_drilldown)
            Drilldown.new(n_hits, items)
          end if raw_drilldowns
        end

        Drilldown = Struct.new(:n_hits, :items)
      end
    end
  end
end

