require 'sinatra/torrent/helpers'

namespace :hash do
  begin
    torrent_db = Sinatra::Torrent::Database.new
  rescue NameError
    raise RuntimeError, "Please require a sinatra-torrent database adapter in your rakefile."
  end

  task :add do
    ARGV[1..-1].each do |rel_location|
      if (File.exists?(File.join(Sinatra::Torrent.downloads_directory,rel_location)))
        torrent_db.add_hashjob(rel_location)
        $stdout.puts "added to queue: #{rel_location}"
      else
        $stderr.puts "#{rel_location} doesn't exist in the downloads directory"
      end
    end
  end

  task :all do
    completed = 0
    failed = 0
    
    Dir[File.join(Sinatra::Torrent.downloads_directory,'**')].each do |filename|
      rel_location = filename[Sinatra::Torrent.downloads_directory.length+1..-1]
      
      begin
        if !torrent_db.torrent_by_path_and_timestamp(rel_location,File.mtime(filename))
          d = Sinatra::Torrent.create(filename)
          
          torrent_db.store_torrent(rel_location,File.mtime(filename),d['metadata'],d['infohash'])
        
          torrent_db.remove_hashjob(rel_location)
          $stdout.puts "Hashed: #{rel_location}"
          
          completed += 1
        else
          $stdout.puts "Already hashed: #{rel_location}"
        end
      rescue
        $stderr.puts "Not hashed: #{rel_location} (Unknown error)"
        failed += 1
      end
    end
    
    $stdout.puts "#{completed} hash job#{(completed == 1) ? '' : 's'} completed sucessfully"
    $stderr.puts "#{failed} failed!" unless failed == 0
  end
  
  task :queue do
    completed = 0
    failed = 0
    
    torrent_db.list_hashjobs.each do |rel_location|
      filename = File.join(Sinatra::Torrent.downloads_directory,rel_location)
      begin
        if torrent_db.torrent_by_path_and_timestamp(rel_location,File.mtime(filename))
          torrent_db.remove_hashjob(rel_location)
        else
          d = Sinatra::Torrent.create(filename)
        
          torrent_db.store_torrent(rel_location,File.mtime(filename),d['metadata'],d['infohash'])
        
          completed += 1
          torrent_db.remove_hashjob(rel_location)
        end
      rescue Errno::ENOENT
        $stderr.puts "#{rel_location} no longer exists to be hashed. Removing job."
        torrent_db.remove_hashjob(rel_location)
        
        failed += 1
      rescue
        $stderr.puts "Uncaught failure reason for #{rel_location}"
        # TODO: trace?
        failed += 1
      end
    end
    
    $stdout.puts "#{completed} queued hash job#{(completed == 1) ? '' : 's'} completed sucessfully"
    $stderr.puts "#{failed} failed!" unless failed == 0
  end
end