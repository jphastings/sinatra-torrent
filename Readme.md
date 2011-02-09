Sinatra-Torrent
===============

There was [a /. article](http://ask.slashdot.org/story/10/10/04/0035231) about BitTorrent replacing standard downloads and I thought: Yes.

Ruby doesn't appear to like BitTorrent very much, most libraries are pretty old and I figured I'd spruce up my favourite jazz legend themed DSL with a library to make serving torrents *ridiculously* easy.

Usage
-----

    require 'sinatra'
    require 'sinatra/torrent'

"Woah, that's pretty simple!" I hear you say. Why yes, I think it is.

All files you put in the `downloads` directory at the root of your sinatra app will be downloadable at `/downloads/your_file.ext` and it's torrent will be dynamically generated (and cached) at `/torrents/your_file.ext.torrent`. You will have trouble with larger files as it currently hashes as part of the request first time round. I'm planning on pushing this out to workers at some point. Not yet sure how I'm going to do that…

### I want options!

There needs to be a database of torrents and peers, this is taken care of by a database adapter. Currently I've written (a really basic) one for active record, so many databases are supported as is, but you can write your own for others (eg. mongo). I'm still finding my way around the Sinatra extensions api, so this is how you specify your own ActiveRecord settings:

    require 'sinatra'
    require 'sinatra/torrent/activerecord'
    SinatraTorrentDatabase.settings = {
	  'adapater' => 'sqlite3',
	  'database' => 'torrents.db'
    }
    require 'sinatra/torrent'

Rake
----

If a torrent takes longer than 1 second to generate on-the-fly, it'll be added to a queue for processing in a background task. If you require a special script in your Rakefile you'll be able to process the queue, add to it or pre-hash all the files in your download directory:

	require 'rake'
	
	# These need to be the same adaptor and settings as your app, of course!
	require 'sinatra/torrent/activerecord'
	Sinatra::Torrent::Database.settings = {
	  'adapter' => 'sqlite3',
	  'database' => 'torrents.db'
	}
	require 'sinatra/torrent/hashing'
	
	# This line is optional, 'downloads' is the default
	# If you've used `set :download_directory, 'files'` in your sinatra app, you need to do:
	Sinatra::Torrent::DOWNLOAD_DIRECTORY = 'files'
	
	# The rest of your Rakefile

* `rake hash:add filename.ext` will add `filename.ext` inside your download directory to the hash queue
* `rake hash:queue` will process all the hash jobs in the queue (you may want to set up a cron job to run this)
* `rake hash:all` will hash all files in the downloads directory right now, so none will be processed on-the-fly when the .torrent file is downloaded

To Do
-----

* Execute a user-writen block of code when an on-the-fly torrent creation times out. This will allow people to trigger the background rake task immediately, rather than waiting on cron.

Ummmm
-----

That's it for now. If you have any feed back - get in touch! You can use [twitter](http://twitter.com/jphastings), [github issues](http://github.com/jphastings/sinatra-torrent/issues) or any other medium you can think of.
