# -*- mode: ruby -*-
#
# Copyright (C) 2013-2024  Sutou Kouhei <kou@clear-code.com>
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

source "https://rubygems.org/"

gemspec

gem "bundler"
gem "packnga"
gem "rake"
gem "redcarpet"
gem "test-unit"

base_dir = File.dirname(__FILE__)
local_chupa_text_dir = File.join(base_dir, "..", "chupa-text")
if File.exist?(local_chupa_text_dir)
  gem "chupa-text", :path => local_chupa_text_dir
end
