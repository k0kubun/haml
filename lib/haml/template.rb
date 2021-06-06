# frozen_string_literal: true

require 'haml/template/options'
if defined?(ActiveSupport)
  ActiveSupport.on_load(:action_view) do
    require 'haml/helpers/action_view_mods'
    require 'haml/helpers/action_view_extensions'
  end
else
  require 'haml/helpers/action_view_mods'
  require 'haml/helpers/action_view_extensions'
end
require 'haml/helpers/xss_mods'
require 'haml/helpers/action_view_xss_mods'

module Haml
  module Helpers
    include Haml::Helpers::XssMods
  end

  module Util
    undef :rails_xss_safe? if defined? rails_xss_safe?
    def rails_xss_safe?; true; end
  end

end


Haml::Template.options[:escape_html] = true

require 'haml/plugin'
