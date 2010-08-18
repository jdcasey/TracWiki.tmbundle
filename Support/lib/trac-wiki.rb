#!/usr/bin/env ruby

SUPPORT = ENV['TM_SUPPORT_PATH']
DIALOG = "#{SUPPORT}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog"
RAW='.raw'
ORIG='.orig'

URL = ENV['TRAC_WIKI_URL']
USER = ENV['TRAC_WIKI_USER']
PASS = ENV['TRAC_WIKI_PASSWORD']
PROXY_HOST = ENV['TRAC_WIKI_PROXY_HOST']
PROXY_PORT = ENV['TRAC_WIKI_PROXY_PORT']


require 'rubygems'
require 'trac4r'
require 'ftools'
# require 'open3'
require SUPPORT + '/lib/ui'

class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

class TracWiki
  
  def initialize
    @trac = Trac.new( URL, USER, PASS, PROXY_HOST, PROXY_PORT )
  end
  
  def list
    pages = @trac.wiki.list
    page_progress = 100/pages.size
    
    IO.popen( "#{DIALOG} progressbar --title 'Listing pages...'", 'w+' ) do |stdin|
      0.upto( pages.size ) do |idx|
        page = pages[idx]
        next unless page
        
        pct = idx * page_progress
        stdin.puts "#{pct} #{pct}% Getting information about #{page}"
        stdin.flush
        
        info = @trac.wiki.get_info( page )
        puts "#{page} [version: #{info['version']}, date: #{info['lastModified'].to_time}]" unless info["author"] == 'trac'
      end
      
      stdin.puts "100% done"
    end
  end
  
  def open()
    page = STDIN.gets
    page = TextMate::UI.request_string( {:title=>'Enter Page Name', :prompt=>"What page do you want to open?", :default=>"WikiStart"}) unless page
    
    if ( !page || page == '?' )
      listing = @trac.wiki.list
      pg_idx = TextMate::UI.menu( listing )
      page = listing[pg_idx]
    end
    
    if ( page )
      fname = "/tmp/#{page}#{RAW}"
      orig_fname = "#{fname}#{ORIG}"

      info = @trac.wiki.get_info( page )

      if info != 0
        content = @trac.wiki.get_raw( page )
      else
        content = ''
      end

      File.open( fname, 'w' ) {|file| file.puts content}
      File.open( orig_fname, 'w' ) {|file| file.puts content}

      system( "mate -r #{fname}" )

      puts "Opened page #{page}"
    else
      puts "Invalid page: '#{page}'"
    end
  end
  
  def save( file )
    if File.exists?( file )
      page = File.basename( file )
      page = page[0..(-1 * ( RAW.length + 1 ) )] if page[RAW]
      page = TextMate::UI.request_string( {:title=>'Save As...', :prompt=>"Wiki page name: ", :default=>page})

      original_file = "#{file}#{ORIG}"

      new_content = File.read( file )
      content = File.read( original_file )

      if content != new_content
        @trac.wiki.put( page, new_content )
        message = "Wrote page #{page}"
      else
        message = "Not changed. Nothing written."
      end
    else
      message = "Please save this file on the filesystem before saving to Trac."
    end
    
    puts message
  end
  
  def save_new
    content = STDIN.read
    
    if ( content )
      begin
        page = TextMate::UI.request_string( {:title=>'Save As...', :prompt=>"Wiki page name: "}).chomp
        page = nil unless page.length > 0
      end until page
      
      @trac.wiki.put( page, content )
      message = "Created page #{page}"
    else
      message = "Empty document will not be saved."
    end
    
    puts message
  end
    

end