Sinatra-Torrent
===============

There was [a /. article](http://ask.slashdot.org/story/10/10/04/0035231) about BitTorrent replacing standard downloads and I thought: Yes.

Ruby doesn't appear to like BitTorrent very much, most libraries are pretty old and I figured I'd spruce up my favourite jazz legend themed DSL with a library to make serving torrents *ridiculously* easy.

Usage
-----

    require 'sinatra'
    require 'sinatra/torrent'

"Woah, that's pretty simple!" I hear you say. Why yes, I think it is.

All files you put in the `downloads` directory at the root of your sinatra app will be downloadable at `/downloads/your_file.ext` and it's torrent will be dynamically generated (and cached) at `/torrents/your_file.ext.torrent`. If a torrent file takes over 1 second to be generated, it'll be put in a queue for creation in a background job. You can run these background jobs using the Rake helper (see below).

If you have set the `:torrent_timeout` sinatra setting to a `Proc`, it will be run (synchronously!) after the delayed job has been queued and before the user is sent the error message. eg. `set :torrent_timeout, Proc.new { start_process_forked_running_rake_hash_queue }`

### I want options!

There needs to be a database of torrents, peers and background hashing jobs, this is taken care of by a database adapter. Currently I've written (a really basic) one for active record, so many databases are supported as is, but you can write your own for others (eg. mongo). I'm still finding my way around the Sinatra extensions api, so this is how you specify your own ActiveRecord settings:

    require 'sinatra'
    require 'sinatra/torrent/activerecord'
    Sinatra::Torrent::Database.settings = {
	  'adapater' => 'sqlite3',
	  'database' => 'torrents.db'
    }
    require 'sinatra/torrent'

The active record adapter is loaded by default if no others are specified and an SQLite database will be maintained in memory unless options (like those above) are specified. This means that, unless you set settings like this, when your app shuts down your hashes will be lost!

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
	Sinatra::Torrent.downloads_directory = 'files'
	
	# The rest of your Rakefile

* `rake hash:add filename.ext` will add `filename.ext` inside your download directory to the hash queue
* `rake hash:queue` will process all the hash jobs in the queue (you may want to set up a cron job to run this)
* `rake hash:all` will hash all files in the downloads directory right now, so none will be processed on-the-fly when the .torrent file is downloaded

To Do
-----

* Get the BitTornado webseed style to work.

Ummmm
-----

That's it for now. If you have any feed back - get in touch! You can use [twitter](http://twitter.com/jphastings), [github issues](http://github.com/jphastings/sinatra-torrent/issues) or any other medium you can think of.
