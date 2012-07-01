require 'timeout'
require 'sinatra/base'
require 'sinatra/torrent/helpers'

# This extension will serve up the contents of the specified folder as web seeded torrents.
# Both webseed versions are supported (shad0w's and GetRight's) and there is an inbuilt tracker
# with a modicum of intelligence, though an external tracker can be used if desired.

module Sinatra
  module Torrent
    # Sets the settings for the app
    def self.settings=(settings = {})
      @@settings = {
        # Directory which holds all the files which will be provided as torrents
        :downloads_directory => File.join(File.dirname(__FILE__),Sinatra::Torrent.downloads_directory),
        # Mount point for the downloads directory
        :downloads_mount => 'downloads',
        # Mount point for the torrents directory
        :torrents_mount => 'torrents'
      }
      settings.each { |key,value| @@settings[key] = value unless @@settings[value].nil? }
    end

    # settings etc
    def self.registered(app)
      # Set default settings
      begin @@settings rescue self.settings=({}) end
      # Putting the annouce URL of a tracker in here will use that tracker rather than the inbuilt one
      app.set :external_tracker, nil
      # Load up a database adapter if one isn't already loaded
      require 'sinatra/torrent/activerecord' unless (Sinatra::Torrent.const_defined?('Database') rescue false)
      # Stores the instance of the database used to store tracker info.
      app.set :database_adapter, Sinatra::Torrent::Database.new
      # The comment added into torrents
      app.set :torrent_comment, ''
      # Do we wish to track external torrents too? (untested)
      app.set :allow_external_torrents, false
      # The frequency with which we ask trackers to announce themselves. Once every x seconds
      app.set :announce_frequency, 900
      # Method to call when torrent creation timesout
      app.set :torrent_timeout, nil
      
# TORRENTS

      app.mime_type :torrent, 'application/x-bittorrent'

      # Serves up the torrents with appropriate announce URL
      app.get Regexp.new("^/#{@@settings[:torrents_mount]}/(.+)\.torrent$") do |rel_location|
        filename = File.join(@@settings[:downloads_directory], rel_location)
        halt(404, "That file doesn't exist! #{filename}") unless File.exists?(filename)
        
        if !(d = settings.database_adapter.torrent_by_path_and_timestamp(rel_location,File.mtime(filename)))
          begin
            Timeout::timeout(1) do
              d = Sinatra::Torrent.create(filename)
            end
          rescue Timeout::Error
            eta = settings.database_adapter.add_hashjob(rel_location)
            
            begin
              wait = case (eta/60).floor
              when 0
                'under a minute'
              when 1
                'about a minute'
              else
                "about #{(eta/60).floor} minutes"
              end
            rescue NoMethodError
              wait = "a short while"
            end
            
            settings.torrent_timeout.call if settings.torrent_timeout.is_a?(Proc)
            
            halt(503,"This torrent is taking too long to build, we're running it in the background. Please try again in #{wait}.")
          end
          
          settings.database_adapter.store_torrent(rel_location,File.mtime(filename),d['metadata'],d['infohash'])
        end
        
        # These are settings which could change between database retrievals
        d['metadata'].merge!({
# Webseeds not currently supported
#          'httpseeds' => [File.join('http://'+env['HTTP_HOST'],URI.encode(settings.torrents_mount),'webseed')],
          'url-list' => [File.join('http://'+env['HTTP_HOST'],URI.encode(@@settings[:downloads_mount]),URI.encode(rel_location)+'?'+d['infohash'])],
          'announce' => settings.external_tracker || File.join('http://'+env['HTTP_HOST'],URI.encode(@@settings[:torrents_mount]),'announce'),
          'comment' => settings.torrent_comment,
        })
        
        content_type :torrent, :charset => 'utf-8'
        d['metadata'].bencode
      end
      
# TRACKER
      
      # Tracker announce mount point
      app.get "/#{@@settings[:torrents_mount]}/announce" do
        # Convert to a hex info_hash if required TODO: Is it required?
        params['info_hash'] = Digest.hexencode(params['info_hash'] || '')
        halt(400,"A valid info-hash was not given") if params['info_hash'].match(/^[0-9a-f]{40}$/).nil?
        info = settings.database_adapter.torrent_info(params['info_hash'])
        
        if (!settings.allow_external_torrents and !settings.database_adapter.torrent_by_infohash(params['info_hash']))
          return {
            'failure reason' => 'This tracker does not track that torrent'
          }.bencode
        end
        
        # TODO: Validation
        
        params['ip'] ||= env['REMOTE_ADDR']
        
        # Errmmm - HACK!
        params['peer_id'] = params['peer_id'].force_encoding("ISO-8859-1")
        
        # Registers this peer's announcement
        settings.database_adapter.announce(params)

        {
          'interval' => settings.announce_frequency,
          #'tracker id' => 'bleugh', # TODO: Keep this?
          'complete' => info['complete'],
          'incomplete' => info['incomplete'],
          'peers' => settings.database_adapter.peers_by_infohash(params['info_hash'],[params['peer_id']],(params['numwant'] || 50).to_i),
        }.bencode
      end
      
      # TODO: Scrape
      app.get '/torrents/scrape' do
        {
          'files' => Hash[*request.env['QUERY_STRING'].scan(/info_hash=([0-9a-f]{20})/).collect do |infohash|
            torrent = settings.database_adapter.torrent_by_infohash(infohash[0])
            next if !torrent
            stats = settings.database_adapter.torrent_info(infohash[0])
            [
              torrent['infohash'],
              {
                'complete'   => stats['complete'],
                'downloaded' => 0,
                'incomplete' => stats['incomplete'],
                'name'       => File.basename(torrent['path'])
              }
            ]
          end.compact.flatten]
        }.bencode
      end

# INDEX PAGE

      app.get "/#{@@settings[:torrents_mount]}/" do
        locals = {:torrents => (Dir.glob("#{@@settings[:downloads_directory]}/**").collect {|f| {:file => f[@@settings[:downloads_directory].length+1..-1],:hashed? => settings.database_adapter.torrent_by_path_and_timestamp(f[@@settings[:downloads_directory].length+1..-1],File.mtime(f)) != false} } rescue [])}
        begin
          haml :torrents_index,:locals => locals
        rescue Errno::ENOENT
          "<ul>"<<locals[:torrents].collect{|t| "<li><a href=\"/#{@@settings[:torrents_mount]}/#{t[:file]}.torrent\" class=\"#{(t[:hashed?] ? 'ready' : 'unhashed')}\">#{t[:file]}</a></li>" }.join<<"</ul>"
        end
      end

# DATA

=begin : Not currently supported
      # BitTornado WebSeeding manager
      # http://bittornado.com/docs/webseed-spec.txt
      app.get "/#{settings.torrents_mount}/webseed" do
        # Which file is the client looking for?
        halt(404, "Torrent not tracked") unless (d = settings.database_adapter.torrent_by_infohash(params[:infohash]))
        
        
      end
=end
      
      # Provides the files for web download. Any query parameters are treated as a checksum for the file (via the torrent infohash)
      app.get "/#{@@settings[:downloads_mount]}/:filename" do
        filename = File.join(@@settings[:downloads_directory],File.expand_path('/'+params[:filename]))
        halt(404) unless File.exists?(filename)
        
        # If there are query params then we assume it's specifying a specific version of the file by info_hash
        halt(409,"The file is no longer the same as the one specified in your torrent") if !env['QUERY_STRING'].empty? and (settings.database_adapter.torrent_by_path_and_timestamp(filename,File.mtime(filename))['infohash'] rescue nil) != env['QUERY_STRING'] 
        send_file(filename)
      end
    end
  end
  
  register Torrent
end
