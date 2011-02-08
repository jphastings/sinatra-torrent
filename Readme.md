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

**NB.** Files that take longer than 1s to hash will fail at the moment!

The extension is in it's early stages at the moment, so many of the settings aren't adhered to, and there are some issues with the webseeding… however it *does* work.

### I want options!

There needs to be a database of torrents and peers, this is taken care of by a database adapter. Currently I've written (a breally basic) one for active record, so many databases are supported. I'm still finding my way around the Sinatra extensions api, so this is how you specify your own ActiveRecord settings:

    require 'sinatra'
    require 'sinatra/torrent/activerecord'
    SinatraTorrentDatabase.settings = {
	  'adapater' => 'sqlite3',
	  'database' => 'torrents.db'
    }
    require 'sinatra/torrent'

Ummmm
-----

That's it for now. If you have any feed back - get in touch! You can use [twitter](http://twitter.com/jphastings), [github issues](http://github.com/jphastings/sinatra-torrent/issues) or any other medium you can think of.
