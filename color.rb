require 'open-uri'
require 'nokogiri'

class ColorPalette

    @@site_name

    def initialize(url)
        url = check_url(url)
        @@site_name = URI.parse(url).host
        # hashmap with store color -> # of appearances
        @color_map = Hash.new
        urls = get_stylesheet_urls(url)
        build_color_palette(urls)
        sort_palette
    end

    def check_url(url)
        url = "http://" + url if !url.start_with?("http", "https", "ftp")
        url = url.chomp('/') if url.end_with? '/' # chomp will making concatenating relative css files to url easier 
        return url
    end

    def get_stylesheet_urls(url)
        urls = Array.new
        begin
            page = Nokogiri::HTML(open(url))      
        rescue
            abort("Not a valid link. Try another one.")
        end
        page.css('head').css('link[rel=stylesheet]').each {|stylesheet|
            if !stylesheet['href'].start_with? '/' 
                css_url = stylesheet['href']
            else
                css_url = url +  stylesheet['href'] # local files, must add to url for uri parsing
            end
            urls << css_url
        }
        urls
    end

    def build_color_palette(urls)
        urls.each{ |css_url|
        #    puts css_url
            begin
                page_source = Nokogiri::HTML(open(css_url)).text 
            rescue
                puts "Did not pull any colors from badly formed url:\n"+css_url
                next
            end
            page_source = Nokogiri::HTML(open(css_url)).text 
            # |color| will be an array of 5 elements (5 regex groups)
            # group 1: hex
            # group 2,3,4: rgb respectively notes: handles rgba but ignores opacity
            # group 5: a color (as an English word -- ex. white)
            color_array = page_source.scan(/color\s*:\s*(#[0-9A-Fa-f]{3,6}+)\s*|rgba?\s*\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*|color\s*:\s*(white|aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|olive|orange|purple)/)
            color_array.each{|color|
                #puts color.inspect
                if color[0] != nil
                    color = color[0].downcase
                    color = expand_hex(color) if color.length == 4 # usually length 3 but including '#' so use length 4
                elsif color[1] != nil
                    color = "#" + color[1].to_i.to_s(16) + color[2].to_i.to_s(16) + color[3].to_i.to_s(16)
                    # below is the case that you have r: 0 g: 0 b: 0 => #000 .... need to expand
                    color = expand_hex(color) if color.length == 4 # usually length 3 but including '#' so use length 4 
                else
                    color = color[4].downcase
                    hex_color = get_hex(color)
                    color = hex_color if hex_color != nil # try to assign a hex value, if not, will remain as is.
                end
                #puts color
                if @color_map[color] == nil
                    @color_map[color] = 1   
                else
                    @color_map[color] += 1
                end
            } 
        }
    end

    # helper method for build_color_palette
    def get_hex(color) 
        hex = case color
        when "white"    then "#ffffff"        
        when "black"    then "#000000"
        when "blue"     then "#0000ff"
        when "fuchsia"  then "#ff00ff"
        when "gray"     then "#808080"
        when "green"    then "#008000"
        when "lime"     then "#00ff00"
        when "maroon"   then "#800000"
        when "olive"    then "#808000"
        when "orange"   then "#ffA500"
        when "purple"   then "#800080"
        end  
    end
    
    # helper method for build_color_palette
    def expand_hex(color)
        new_hex = color[0]
        for i in 1..3
            new_hex += color[i]+color[i]
        end
        new_hex
    end
    
    # will sort hash map and add those keys to an array then return array
    def sort_palette
        @color_palette = Array.new
        @color_map = @color_map.sort_by {|k,v| v}.reverse
        @color_map.each{|key, value|
            @color_palette << key
        }
        #    color_palette.each{|color| puts color}
        return @color_palette
    end

    def print_palette_html
        file = File.new("#{@@site_name}.html", "w+")
        file.puts "<html>"
        file.puts "<title>#{@@site_name} Color Page</title>"
        file.puts "<body>"
        file.puts "<table>"
        file.puts "<tr>"
        file.puts "<th> Color </th>"
        file.puts "<th> Hex </th>"
        file.puts "<th> Frequency </th>"
        file.puts "</tr>"
        @color_map.each{|key, value|
            file.puts "<tr>"
            file.puts "<td style='width:50px; height:50px; background-color: #{key}'></td>"
            file.puts "<td> #{key} </td>"
            file.puts "<td> #{value} </td>"
            file.puts "</tr>"
        }
        file.puts "</body>"
        file.puts "</html>"
    end

    def print_color_palette
        @color_palette.each{|c| puts c}
    end

    def print_palette_with_freq
        puts "number of unique colors: " + @color_map.size.to_s
        printf("--------|-----------\n")
        printf("%.8s\t|%s\n", "Color", "Frequency")
        printf("--------|-----------\n")
        @color_map.each{|key, value|
            printf("%.8s |%d\n", key, value)
        }

    end
end

if ARGV.length == 0
    abort("must provide a url")
elsif ARGV.length > 1
    abort("Too much info, buddy. I just need one url.")
elsif ARGV.length == 1
    param_url = ARGV[0]
end

cp = ColorPalette.new("#{param_url}")
puts "Palette for " + param_url
cp.print_palette_with_freq
cp.print_palette_html
