#!/usr/bin/env ruby

require "fileutils"
require "rexml/document"
require "rexml/formatters/pretty"
require "rexml/xpath"

source_path, destination_path = ARGV
abort "usage: extract_effekseer_finish.rb SOURCE DESTINATION" unless source_path && destination_path

document = REXML::Document.new(File.read(source_path))
finish = REXML::XPath.first(document, "//Node[Name='Finish']")
abort "Finish node not found in #{source_path}" unless finish

project = document.root
root = project.elements["Root"]
children = root.elements["Children"]
children.elements.to_a.each { |child| children.delete(child) }

impact = finish.deep_clone
impact.elements["Name"].text = File.basename(destination_path, ".efkproj")
offset = impact.elements["CommonValues/GenerationTimeOffset"]
offset&.elements&.each do |value|
  value.text = "0" if %w[Center Max Min].include?(value.name)
end

# Optional frost palette. The source FireBall finish already has the mature
# timing, volume and breakup we want; this changes authored vertex colours
# only, leaving the approved source project and all source textures untouched.
if ENV["MINDSTONE_FROST_PALETTE"] == "1"
  def set_text(parent, name, value)
    element = parent.elements[name] || parent.add_element(name)
    element.text = value.to_i.to_s
  end

  def set_fixed_rgb(element, rgb)
    set_text(element, "R", rgb[0])
    set_text(element, "G", rgb[1])
    set_text(element, "B", rgb[2])
  end

  def set_random_rgb(element, rgb, spread = 12)
    %w[R G B].zip(rgb).each do |channel, value|
      component = element.elements[channel] || element.add_element(channel)
      set_text(component, "Center", value)
      set_text(component, "Max", [value + spread, 255].min)
      set_text(component, "Min", [value - spread, 0].max)
    end
  end

  fire_palette = [
    [24, 224, 255],
    [109, 74, 255],
    [36, 255, 176],
    [222, 102, 255]
  ]
  flash_palette = [[246, 255, 248], [136, 242, 255]]
  ember_palette = [[188, 246, 255], [244, 176, 255]]
  fire_index = 0
  flash_index = 0
  ember_index = 0

  REXML::XPath.match(impact, ".//Node").each do |node|
    name = node.elements["Name"]&.text
    drawing = node.elements["DrawingValues"]
    next unless drawing

    fixed_colors = REXML::XPath.match(drawing, ".//*[contains(name(), '_Fixed') and contains(name(), 'Color')]")
    random_colors = REXML::XPath.match(drawing, ".//*[contains(name(), '_Random') and contains(name(), 'Color')]")

    case name
    when "Wind"
      fixed_colors.each do |color|
        rgb = if color.name.start_with?("Center")
                [212, 255, 239]
              elsif color.name.start_with?("Inner")
                [151, 86, 255]
              else
                [34, 186, 255]
              end
        set_fixed_rgb(color, rgb)
      end
    when "Light"
      fixed_colors.each { |color| set_fixed_rgb(color, [216, 255, 246]) }
      random_colors.each { |color| set_random_rgb(color, [120, 238, 255], 16) }
    when "FireVariation"
      rgb = fire_palette[fire_index % fire_palette.length]
      fire_index += 1
      fixed_colors.each { |color| set_fixed_rgb(color, rgb) }
      random_colors.each { |color| set_random_rgb(color, rgb, 18) }
    when "SmokeVariation"
      fixed_colors.each { |color| set_fixed_rgb(color, [24, 62, 104]) }
      random_colors.each { |color| set_random_rgb(color, [42, 30, 86], 12) }
    when "EmberVariation"
      rgb = ember_palette[ember_index % ember_palette.length]
      ember_index += 1
      fixed_colors.each { |color| set_fixed_rgb(color, rgb) }
      random_colors.each { |color| set_random_rgb(color, rgb, 20) }
    when "Flash"
      rgb = flash_palette[flash_index % flash_palette.length]
      flash_index += 1
      fixed_colors.each { |color| set_fixed_rgb(color, rgb) }
      random_colors.each { |color| set_random_rgb(color, rgb, 8) }
    when "Tracker", "SparkEmitter", "Node"
      fixed_colors.each { |color| set_fixed_rgb(color, [150, 232, 255]) }
      random_colors.each { |color| set_random_rgb(color, [190, 154, 255], 18) }
    end
  end
end

# The source finish contains two long tracker chains and one star-shaped ray.
# Those are attractive in the sword sample but become the thick geometric
# lines that were explicitly rejected for Mindstone's frost tornado.
REXML::XPath.match(impact, ".//Node").each do |node|
  name = node.elements["Name"]&.text
  next unless %w[WindTracker Ray].include?(name)

  node.parent.delete(node)
end

children.add_element(impact)
project.elements["EndFrame"].text = "120"
project.elements["IsLoop"].text = "False"
if (culling_type = project.elements["Culling/Type"])
  culling_type.text = "0"
end

FileUtils.mkdir_p(File.dirname(destination_path))
formatter = REXML::Formatters::Pretty.new(2)
formatter.compact = true
File.open(destination_path, "w") do |file|
  formatter.write(document, file)
  file.write("\n")
end
