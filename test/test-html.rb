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

require "pathname"

class TestHTML < Test::Unit::TestCase
  def setup
    @decomposer = ChupaText::Decomposers::HTML.new({})
  end

  private
  def fixture_path(*components)
    base_path = Pathname(__FILE__).dirname + "fixture"
    base_path.join(*components)
  end

  sub_test_case("target?") do
    sub_test_case("source-mime-type") do
      def create_data(uri, mime_type)
        data = ChupaText::Data.new
        data.body = ""
        data.uri = uri
        data["source-mime-types"] = [mime_type]
        data
      end

      def test_text_html
        data = create_data("index.html", "text/html")
        assert do
          not @decomposer.target?(data)
        end
      end

      def test_application_xhtml_xml
        data = create_data("index.html", "application/xhtml+xml")
        assert do
          not @decomposer.target?(data)
        end
      end
    end

    sub_test_case("extension") do
      def create_data(uri)
        data = ChupaText::Data.new
        data.body = ""
        data.uri = uri
        data
      end

      def test_html
        assert_true(@decomposer.target?(create_data("index.html")))
      end

      def test_htm
        assert_true(@decomposer.target?(create_data("index.htm")))
      end

      def test_xhtml
        assert_true(@decomposer.target?(create_data("index.xhtml")))
      end

      def test_txt
        assert_false(@decomposer.target?(create_data("index.txt")))
      end

      def test_php
        assert do
          not @decomposer.target?(create_data("index.php"))
        end
      end
    end

    sub_test_case("mime-type") do
      def create_data(mime_type)
        data = ChupaText::Data.new
        data.mime_type = mime_type
        data
      end

      def test_html
        assert_true(@decomposer.target?(create_data("text/html")))
      end

      def test_xhtml
        assert_true(@decomposer.target?(create_data("application/xhtml+xml")))
      end

      def test_txt
        assert_false(@decomposer.target?(create_data("text/plain")))
      end
    end

    sub_test_case("content") do
      def create_data(body)
        data = ChupaText::Data.new
        data.body = body
        data
      end

      def test_doctype_html
        assert do
          @decomposer.target?(create_data("<!DOCTYPE html "))
        end
      end

      def test_html
        assert do
          @decomposer.target?(create_data("<html"))
        end
      end
    end
  end

  sub_test_case("decompose") do
    def setup
      super
      @data = ChupaText::Data.new
      @data.mime_type = "text/html"
    end

    def decompose(data)
      decomposed = []
      @decomposer.decompose(data) do |decomposed_data|
        decomposed << normalize_decomposed_data(decomposed_data)
      end
      decomposed
    end

    sub_test_case("title") do
      def normalize_decomposed_data(decomposed_data)
        {
          :title => decomposed_data["title"],
          :body  => decomposed_data.body,
        }
      end

      def test_no_title
        @data.body = <<-HTML
<html>
  <body>Hello</body>
</html>
        HTML
        assert_equal([
                       {
                         :title  => nil,
                         :body   => "Hello",
                       },
                     ],
                     decompose(@data))
      end

      def test_have_title
        @data.body = <<-HTML
<html>
  <head>
   <title>Hello</title>
  </head>
  <body>World</body>
</html>
        HTML
        assert_equal([
                       {
                         :title  => "Hello",
                         :body   => "World",
                       },
                     ],
                     decompose(@data))
      end
    end

    sub_test_case("encoding") do
      def normalize_decomposed_data(decomposed_data)
        decomposed_data["encoding"]
      end

      sub_test_case("detect") do
        def test_nothing
          @data.body = <<-HTML.force_encoding("UTF-8")
<html>
  <body>Hello</body>
</html>
          HTML
          assert_equal([Encoding::UTF_8], decompose(@data))
        end

        def test_xml_declaration
          @data.body = <<-XHTML
<?xml encoding="Shift_JIS"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
  </head>
  <body>Hello</body>
</html>
          XHTML
          assert_equal([Encoding::Shift_JIS], decompose(@data))
        end

        def test_content_type
          @data.body = <<-HTML
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=EUC-JP">
  </head>
  <body>Hello</body>
</html>
          HTML
          assert_equal([Encoding::EUC_JP], decompose(@data))
        end

        def test_meta_charset
          @data.body = <<-HTML5
<html>
  <head>
    <meta charset="EUC-JP">
  </head>
  <body>Hello</body>
</html>
          HTML5
          assert_equal([Encoding::EUC_JP], decompose(@data))
        end

        sub_test_case("not ascii_compatible?") do
          def test_iso_2022_jp
            @data.body = <<-ISO_2022_JP_HTML.encode("ISO-2022-JP")
<html>
  <head>
    <title>タイトル</title>
  </head>
  <body>Hello</body>
</html>
            ISO_2022_JP_HTML
            assert_equal([Encoding::ISO_2022_JP], decompose(@data))
          end

          def test_utf_32
            @data.body = <<-UTF_32_HTML.encode("UTF-32")
<html>
  <head>
    <title>タイトル</title>
  </head>
  <body>Hello</body>
</html>
            UTF_32_HTML
            assert_equal([Encoding::UTF_32], decompose(@data))
          end

          def test_koi8_r
            @data.body = <<-KOI8_R_HTML.encode("KOI8-R")
<html>
  <head>
    <title>название</title>
  </head>
  <body>Hello</body>
</html>
            KOI8_R_HTML
            assert_equal([Encoding::KOI8_R], decompose(@data))
          end
        end
      end

      sub_test_case("normalize") do
        def decompose(charset)
          @data.body = <<-HTML
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=#{charset}">
  </head>
  <body>Hello</body>
</html>
          HTML
          super(@data)
        end

        def test_x_sjis
          assert_equal([Encoding::WINDOWS_31J], decompose("x-sjis"))
        end

        def test_shift_jis_hyphen
          assert_equal([Encoding::WINDOWS_31J], decompose("Shift-JIS"))
        end

        def test_shift_jis_under_score
          assert_equal([Encoding::WINDOWS_31J], decompose("Shift_JIS"))
        end
      end
    end

    sub_test_case("body") do
      def normalize_decomposed_data(decomposed_data)
        decomposed_data.body
      end

      sub_test_case("noindex") do
        def test_script
          @data.body = <<-HTML
<html>
  <body>Before<script>var x;</script>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_noscript
          @data.body = <<-HTML
<html>
  <body>Before<noscript>Enable JavaScript!</noscript>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_link
          @data.body = <<-HTML
<html>
  <body>Before<link rel="stylehseet">After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_style
          @data.body = <<-HTML
<html>
  <body>Before<style>a {color: "red";}</style>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_noindex
          @data.body = <<-HTML
<html>
  <body>Before<div class="noindex">header</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_robots_noindex
          @data.body = <<-HTML
<html>
  <body>Before<div class="robots-noindex">header</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end
      end

      sub_test_case("header") do
        def test_tag
          @data.body = <<-HTML
<html>
  <body>Before<header>header</header>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_class
          @data.body = <<-HTML
<html>
  <body>Before<div class="header">header</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_id
          @data.body = <<-HTML
<html>
  <body>Before<div id="header">header</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end
      end

      sub_test_case("footer") do
        def test_tag
          @data.body = <<-HTML
<html>
  <body>Before<footer>footer</footer>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_class
          @data.body = <<-HTML
<html>
  <body>Before<div class="footer">footer</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_id
          @data.body = <<-HTML
<html>
  <body>Before<div id="footer">footer</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end
      end

      sub_test_case("navigation") do
        def test_nav_tag
          @data.body = <<-HTML
<html>
  <body>Before<nav>nav</nav>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_nav_class
          @data.body = <<-HTML
<html>
  <body>Before<div class="nav">nav</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_menu_class
          @data.body = <<-HTML
<html>
  <body>Before<div class="menu">nav</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_topic_path_class
          @data.body = <<-HTML
<html>
  <body>
    Before
    <div class="topic-path">topic-path</div>
    <div class="topic_path">topic_path</div>
    <div class="topicpath">topicpath</div>
    <div class="TopicPath">TopicPath</div>
    After
  </body>
</html>
          HTML
          assert_equal(["Before\nAfter"],
                       decompose(@data))
        end

        def test_nav_id
          @data.body = <<-HTML
<html>
  <body>Before<div id="nav">nav</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_menu_id
          @data.body = <<-HTML
<html>
  <body>Before<div id="menu">nav</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_topic_path_id
          @data.body = <<-HTML
<html>
  <body>
    Before
    <div id="topic-path">topic-path</div>
    <div id="topic_path">topic_path</div>
    <div id="topicpath">topicpath</div>
    <div id="TopicPath">TopicPath</div>
    After
  </body>
</html>
          HTML
          assert_equal(["Before\nAfter"],
                       decompose(@data))
        end
      end

      sub_test_case("aside") do
        def test_aside_tag
          @data.body = <<-HTML
<html>
  <body>Before<aside>aside</aside>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_aside_class
          @data.body = <<-HTML
<html>
  <body>Before<div class="aside">aside</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end

        def test_aside_id
          @data.body = <<-HTML
<html>
  <body>Before<div id="aside">aside</div>After</body>
</html>
          HTML
          assert_equal(["BeforeAfter"],
                       decompose(@data))
        end
      end
    end
  end
end
