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
require 'uri'
require SUPPORT + '/lib/ui'
require SUPPORT + '/lib/tm/htmloutput'

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
    page = _read_select_page
    
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

      `open txmt://open?url=file://#{URI.escape(fname)}`

      puts "Opened page #{page}"
    else
      puts "Invalid page: '#{page}'"
    end
  end
  
  def save( file )
    page = nil
    if File.exists?( file )
      page = _write_select_page( file )

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
      page = _write_select_page()
      
      @trac.wiki.put( page, content )
      message = "Created page #{page}"
    else
      message = "Empty document will not be saved."
    end
    
    puts message
  end
    
  def show
    page = _read_select_page( 'display' )
    
    begin
      output = @trac.wiki.get_html( page ) if page
    rescue
      output = nil
    end
    
    output = TextMate::HTMLOutput.show(:title => "#{page} Not Found!") do |io|
      io << "Cannot find page: #{page}"
    end unless output
    
    output
  end
  
  def preview
    content = STDIN.read
    
    begin
      output = @trac.wiki.raw_to_html( content ) if content
    rescue
      output = nil
    end
    
    output = TextMate::HTMLOutput.show(:title => "Nothing to do!") do |io|
      io << "<h1>Nothing to preview!</h1>"
    end unless output
    
    output
  end
  
  def _write_select_page( file = nil )
    if ( file )
      page = File.basename( file )
      page = page[0..(-1 * ( RAW.length + 1 ) )] if page[RAW]
    else
      page = ''
    end
    
    begin
      page = TextMate::UI.request_string( {:title=>'Save As...', :prompt=>"Wiki page name: ", :default=>page}).chomp
      page = _select_from_menu( page )
      page = nil unless page.length > 0
    end until page
    
    page
  end
  
  def _read_select_page( action = 'open' )
    page = TextMate::UI.request_string( {:title=>'Enter Page Name', :prompt=>"What page do you want to #{action}?", :default=>"WikiStart"}) unless page
    page = _select_from_menu( page )
    
    if ( page && page.length < 1 )
      page = nil
    end
    
    page
  end
  
  def _select_from_menu( page )
    if ( page == '?' )
      listing = @trac.wiki.list
      pg_idx = TextMate::UI.menu( listing )
      page = listing[pg_idx]
    end
    
    page
  end

end