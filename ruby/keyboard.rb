#!/usr/bin/env ruby
#
# Copyright:: Copyright 2012 Google Inc.
# License:: All Rights Reserved.
# Original Author:: Ying Yin (mailto:yingyin@google.com)
#
# Summary description of library or script.
#
# This doc string should contain an overall description of the module/script
# and can optionally briefly describe exported classes and functions.
#
#    ClassFoo:      One line summary.
#    function_foo:  One line summary.

# A class that represents a keyboard.
require 'set'

class Keyboard
  LKEYS = Set.new %w(q w e r t a s d f g z x c v b)
  RKEYS = Set.new %w(y u i o p h j k l n m)

  # Checks if the two keys are from left and right sides of the keyboard.
  #
  # @param [char] One key.
  # @param [char] The other key.
  # @return [bool] True if the two keys are from two sides of the keyboard.
  def self.is_lr? k1, k2
    is_l?(k1) && is_r?(k2) || is_l?(k2) && is_r?(k1)
  end

  def self.is_l? k
    LKEYS.include? k
  end

  def self.is_r? k
    RKEYS.include? k
  end

  attr_reader :params

  # Initializes keyboard layout from input stream.
  #
  # @param [IO] Input stream that contains keyboard layout in text.
  def initialize(io)
    @keys = {}
    io.each do |line|
      next if /^\s*#/ =~ line
      tokens = line.chomp.split(',').map(&:strip)
      next if tokens.length < 1
      if tokens[0].length > 1
        params = tokens.map do |t|
          kvp = t.split('=').map(&:strip)
          [kvp[0].to_sym, kvp[1].to_f]
        end
        @params = Hash[params]
      elsif tokens.length == 5
        bounds = tokens[1..-1].map do |t|
          kvp = t.split('=').map(&:strip)
          [kvp[0].to_sym, kvp[1].to_f]
        end
        key = tokens[0].empty? ? ' ' : tokens[0]
        @keys[key] = Hash[bounds]
      end
    end
    raise 'Not enough keys.' if @keys.length < 27
  end

  def lr_of_keyboard?(x1, y1, x2, y2)
    return (lkeyboard?(x1, y1) && rkeyboard?(x2, y2)) ||
           (lkeyboard?(x2, y2) && rkeyboard?(x1, y1))
  end

  # Returns true if (x, y) coordiantes are at the left side of the keyboard.
  #
  # @param [Fixnum] x coordinate relative to the top left of the keyboard.
  # @param [Fixnum] y coordiante relative to the top left of the keyboard.
  def lkeyboard?(x, y)
    return x < @params[:width] / 2
  end

  def rkeyboard?(x, y)
    return !lkeyboard?(x, y)
  end

  # Checks if the relative (x, y) coordinates are in certain key bounds.
  #
  # @param [char] The key in lowercase whose bounds we want to check.
  # @param [Fixnum] The relative x coordinate of the tapping point.
  # @param [Fixnum] The relative y coordinate of the tapping point.
  def in_key_bounds?(key, x, y)
    bounds = @keys[key]
    x += @params[:xoffset]
    y += @params[:yoffset]
    x >= bounds[:left] - @params[:hmargin] / 2 &&
    x <= bounds[:right] + @params[:hmargin] / 2 &&
    y >= bounds[:top] - @params[:vmargin] / 2 &&
    y <= bounds[:bottom] + @params[:vmargin] / 2
  end

  def relative_key_center(key)
    bounds = @keys[key]
    {x: (bounds[:left] + bounds[:right]) / 2 - @params[:xoffset],
     y: (bounds[:top] + bounds[:bottom]) / 2 - @params[:yoffset]}
  end

  def output_relative_coordinates
    puts %w(key top right bottom left xcenter ycenter).join ','
    @keys.each do |k, v|
      xcenter, ycenter = relative_key_center(k).values
      puts [k, v[:top] - @params[:yoffset], v[:right] - @params[:xoffset],
            v[:bottom] - @params[:yoffset], v[:left] - @params[:xoffset],
            xcenter, ycenter].join ','
    end
  end
end

if __FILE__ == $0
  keyboard = Keyboard.new STDIN
  keyboard.output_relative_coordinates
end
