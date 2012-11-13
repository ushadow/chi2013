#!/usr/bin/env ruby
#
# Copyright:: Copyright 2012 Google Inc.
# License:: All Rights Reserved.
# Original Author:: Ying Yin (mailto:yingyin@google.com)
#
# Script that fixes the mis-alignment of transcribed and presented phrases
# from Octopus.
require 'nokogiri'

def main
  io = STDIN
  doc = Nokogiri::Slop io
  tasks = doc.css('task')
  prev_task = tasks.first
  while task = prev_task.next
    prev_task.transcribed.content = task.transcribed.content
    puts prev_task.to_html
    puts
    prev_task = task
  end
end

if __FILE__ == $0
  main()
end

