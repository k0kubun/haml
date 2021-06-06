# frozen_string_literal: true

require 'test_helper'
require "active_model/naming"

class HelpersForRailsTest < Haml::TestCase
  class FormModel
    extend ActiveModel::Naming
  end

  TEXT_AREA_CONTENT_REGEX = /<(textarea)[^>]*>\n(.*?)<\/\1>/im

  Post = Struct.new('Post', :body, :error_field, :errors)
  class PostErrors
    def on(name)
      return unless name == 'error_field'
      ["Really bad error"]
    end
    alias_method :full_messages, :on

    def [](name)
      on(name) || []
    end
  end

  def setup
    context = ActionView::LookupContext.new(File.expand_path("../templates", __FILE__))
    @base = Class.new(ActionView::Base.try(:with_empty_template_cache) || ActionView::Base) {
      def nested_tag
        content_tag(:span) {content_tag(:div) {"something"}}
      end

      def wacky_form
        form_tag("/foo") {"bar"}
      end
    }.new(context, {post: Post.new("Foo bar\nbaz", nil, PostErrors.new)}, ActionController::Base.new)
  end

  def render(text, options = {})
    return @base.render :inline => text, :type => :haml if options == :action_view
    super
  end

  def test_form_tag
    def @base.protect_against_forgery?; false; end
    rendered = render(<<HAML, :action_view)
= form_tag 'foo' do
 %p bar
 %strong baz
HAML
   fragment = Nokogiri::HTML.fragment(rendered)
   assert_equal 'foo', fragment.css('form').first.attributes['action'].to_s
   assert_equal 'bar', fragment.css('form p').first.text.strip
   assert_equal 'baz', fragment.css('form strong').first.text.strip
  end

  def test_form_for
    # FIXME: current HAML doesn't do proper indentation with form_for (it's the capture { output } in #form_for).
    def @base.protect_against_forgery?; false; end
    rendered = render(<<HAML, :action_view)
= form_for OpenStruct.new, url: 'foo', as: :post do |f|
  = f.text_field :name
HAML
    assert_match(/<(form|div)[^>]+><input/, rendered)
  end

  def test_pre
    assert_equal(%(<pre>Foo bar&#x000A;   baz</pre>\n),
                 render('= content_tag "pre", "Foo bar\n   baz"', :action_view))
  end

  def test_text_area_tag
    output = render('= text_area_tag "body", "Foo\nBar\n Baz\n   Boom"', :action_view)
    match_data = output.match(TEXT_AREA_CONTENT_REGEX)
    assert_equal "Foo&#x000A;Bar&#x000A; Baz&#x000A;   Boom", match_data[2]
  end

  def test_text_area
    output = render('= text_area :post, :body', :action_view)
    match_data = output.match(TEXT_AREA_CONTENT_REGEX)
    assert_equal "Foo bar&#x000A;baz", match_data[2]
  end

  def test_partials_should_not_cause_textareas_to_be_indented
    # non-indentation of textareas rendered inside partials
    @base.instance_variable_set(:@post, Post.new("Foo", nil, PostErrors.new))
    output = render(".foo\n  .bar\n    = render '/text_area_helper'", :action_view)
    match_data = output.match(TEXT_AREA_CONTENT_REGEX)
    assert_equal 'Foo', match_data[2]
  end

  def test_textareas_should_preserve_leading_whitespace
    # leading whitespace preservation
    @base.instance_variable_set(:@post, Post.new("    Foo", nil, PostErrors.new))
    output = render(".foo\n  = text_area :post, :body", :action_view)
    match_data = output.match(TEXT_AREA_CONTENT_REGEX)
    assert_equal '&#x0020;   Foo', match_data[2]
  end

  def test_textareas_should_preserve_leading_whitespace_in_partials
    # leading whitespace in textareas rendered inside partials
    @base.instance_variable_set(:@post, Post.new("    Foo", nil, PostErrors.new))
    output = render(".foo\n  .bar\n    = render '/text_area_helper'", :action_view)
    match_data = output.match(TEXT_AREA_CONTENT_REGEX)
    assert_equal '&#x0020;   Foo', match_data[2]
  end

  def test_content_tag_block
    assert_equal(<<HTML.strip, render(<<HAML, :action_view).strip)
<div><p>bar</p>
<strong>bar</strong>
</div>
HTML
= content_tag :div do
  %p bar
  %strong bar
HAML
  end

  def test_content_tag_error_wrapping
    def @base.protect_against_forgery?; false; end
    output = render(<<HAML, :action_view)
= form_for @post, :as => :post, :html => {:class => nil, :id => nil}, :url => '' do |f|
  = f.label 'error_field'
HAML
    fragment = Nokogiri::HTML.fragment(output)
    refute_nil fragment.css('form div.field_with_errors label[for=post_error_field]').first
  end

  def test_form_tag_in_helper_with_string_block
    def @base.protect_against_forgery?; false; end
    rendered = render('= wacky_form', :action_view)
    fragment = Nokogiri::HTML.fragment(rendered)
    assert_equal 'bar', fragment.text.strip
    assert_equal '/foo', fragment.css('form').first.attributes['action'].to_s
  end

  def test_indented_capture
    assert_equal("  Foo\n  ", @base.render(:inline => "  <% res = capture do %>\n  Foo\n  <% end %><%= res %>"))
  end

  def test_capture_with_string_block
    assert_equal("foo\n", render("= capture { 'foo' }", :action_view))
  end

  def test_capture_with_non_string_value_returns_nil
    def @base.check_capture_returns_nil(&block)
      contents = capture(&block)

      contents << "ERROR" if contents
    end

    assert_equal("\n", render("= check_capture_returns_nil { 2 }", :action_view))
  end

  def test_content_tag_nested
    assert_equal "<span><div>something</div></span>", render("= nested_tag", :action_view).strip
  end

  class ActsLikeTag
    # We want to be able to have people include monkeypatched ActionView helpers
    # without redefining is_haml?.
    # This is accomplished via Object#is_haml?, and this is a test for it.
    include ActionView::Helpers::TagHelper
    def to_s
      content_tag :p, 'some tag content'
    end
  end

  def test_random_class_includes_tag_helper
    assert_equal "<p>some tag content</p>", ActsLikeTag.new.to_s
  end
end
