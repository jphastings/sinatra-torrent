# The active record adapter works with SQLite3 in memory by default
require 'active_record'

# This is the wrapper class used by sinatra-torrent to communicate with
# any database system
class SinatraTorrentDatabase
  # Default settings for the connection
  @@settings = {
    'adapter' => 'sqlite3',
    'database' => ':memory:'
  }
  
  # Allows the set up of Active Record 
  def self.settings=(settings)
    raise ArgumentError if !settings.is_a?(Hash)
    @@settings = settings
  end
  
  # Makes sure the table is present & ready, log in using the settings
  def initialize
    @db = ActiveRecord::Base.establish_connection(@@settings)
    
    unless Torrent.table_exists?
      ActiveRecord::Schema.define do
        create_table :torrents do |table|
          table.text :path, :null => false
          table.text :metadata, :null => false
          table.string :infohash, :null => false
          table.timestamp :timestamp, :null => false
        end
        
        add_index :torrents, :infohash, :unique => true
        
        create_table :peers do |table|
          table.string :torrent_infohash, :null => false
          table.string :peer_id
          table.integer :port
          table.integer :uploaded
          table.integer :downloaded
          table.integer :left
          table.string :ip
          
          table.timestamps
        end
        
        add_index :peers, [:peer_id,:torrent_infohash],:unique => true
      end
    end
  end
  
  # Stores a torrent in the database
  def store_torrent(path,timestamp,metadata,infohash)
    # Make sure this path and this infohash don't already exist
    Torrent.find_by_path_and_timestamp(path,timestamp).delete rescue nil
    Torrent.find_by_infohash(infohash).delete rescue nil
    
    Torrent.new(
      :path => path,
      :metadata => metadata,
      :infohash => infohash,
      :timestamp => timestamp
    ).save
  end
  
  # Find a torrent by infohash
  def torrent_by_infohash(infohash)
    torrent = Torrent.find_by_infohash(infohash)
    return false if torrent.nil?
    
    {
      'metadata' => torrent.metadata,
      'infohash' => torrent.infohash,
      'path'     => torrent.path,
      'timestamp'=> torrent.timestamp
    }
  end
  
  # Finds a torrent by 
  def torrent_by_path_and_timestamp(path,timestamp)
    torrent = Torrent.find_by_path_and_timestamp(path,timestamp)
    return false if torrent.nil?
    
    {
      'metadata' => torrent.metadata,
      'infohash' => torrent.infohash,
      'path'     => torrent.path,
      'timestamp'=> torrent.timestamp
    }
  end
  
  # Lists the currently registered peers for a given torrent
  # if peer_ids is populated with any peer ids then they will be excluded from the list
  def peers_by_infohash(infohash, peer_ids = [], peers = 50)
    begin
      # TODO: Random order & actual number of peers (if peer_ids is in returned amount)
      Peer.find_by_torrent_infohash(infohash,:limit => peers).delete_if {|peer| peer_ids.include? peer.peer_id}.map do |peer|
        {
          'peer id' => peer.peer_id,
          'ip'      => peer.ip,
          'port'    => peer.port
        }
      end
    rescue NoMethodError
      []
    end
  end
  
  # Returns information about the torrent as provided by it's infohash
  def torrent_info(infohash)
    info = Peer.find_by_sql(["SELECT (SELECT COUNT(*) FROM 'peers' WHERE `left` != 0 AND `torrent_infohash` = ?) as `incomplete`, (SELECT COUNT(*) FROM 'peers' WHERE `left` == 0 AND `torrent_infohash` = ?) as `complete`",infohash, infohash])[0]
    
    {
      'complete' => info.complete,
      'incomplete' => info.incomplete
    }
  end
  
  # Announce!
  def announce(params)
    peer = Peer.find_or_create_by_torrent_infohash_and_peer_id(params['info_hash'],params['peer_id'])
    
    peer.ip ||= params['ip']
    peer.port ||= params['port']
    peer.uploaded = params['uploaded']
    peer.downloaded = params['downloaded']
    peer.left = params['left']
    
    peer.save
  end
  
  private
  class Torrent < ActiveRecord::Base
    serialize :metadata, Hash
  end
  
  class Peer < ActiveRecord::Base
    
  end
end