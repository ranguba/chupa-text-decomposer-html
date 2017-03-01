# Copyright (C) 2013-2017  Kouhei Sutou <kou@clear-code.com>
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

require "nkf"
require "nokogiri"

module ChupaText
  module Decomposers
    class HTML < Decomposer
      registry.register("html", self)

      TARGET_EXTENSIONS = ["htm", "html", "xhtml"]
      TARGET_MIME_TYPES = [
        "text/html",
        "application/xhtml+xml",
      ]
      def target?(data)
        TARGET_EXTENSIONS.include?(data.extension) or
          TARGET_MIME_TYPES.include?(data.mime_type)
      end

      def decompose(data)
        html = data.body
        doc = Nokogiri::HTML.parse(html, nil, guess_encoding(html))
        body_element = (doc % "body")
        if body_element
          body = body_element.text.gsub(/^\s+|\s+$/, '')
        else
          body = ""
        end
        decomposed_data = TextData.new(body, :source_data => data)
        attributes = decomposed_data.attributes
        title_element = (doc % "head/title")
        attributes.title = title_element.text if title_element
        encoding = doc.encoding
        attributes.encoding = encoding if encoding

        yield(decomposed_data)
      end

      private
      def guess_encoding(text)
        unless text.encoding.ascii_compatible?
          return text.encoding.name
        end

        case text
        when /\A<\?xml.+?encoding=(['"])([a-zA-Z0-9_-]+)\1/
          $2
        when /<meta\s[^>]*
               http-equiv=(['"])content-type\1\s+
               content=(['"])(.+?)\2/imx # "
          content_type = $3
          _, parameters = content_type.split(/;\s*/, 2)
          encoding = nil
          if parameters and /\bcharset=([a-zA-Z0-9_-]+)/i =~ parameters
            encoding = normalize_charset($1)
          end
          encoding
        when /<meta\s[^>]*charset=(['"])(.+?)\1/imx # "
          charset = $2
          normalize_charset(charset)
        else
          if text.encoding != Encoding::ASCII_8BIT and text.valid_encoding?
            text.encoding.to_s
          else
            guess_encoding_nkf(text)
          end
        end
      end

      def normalize_charset(charset)
        case charset
        when /\Ax-sjis\z/i
          normalize_charset("Shift_JIS")
        when /\Ashift[_-]jis\z/i
          "Windows-31J"
        else
          charset
        end
      end

      def guess_encoding_nkf(text)
        NKF.guess(text).name
      end
    end
  end
end
