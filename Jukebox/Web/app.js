'use strict';

// use #hash in url to change server (no trailing slash)
var server = window.location.hash.substr(1);

var Library = (function() {
    var library = {},
        _artists = [],
        _albums  = [],
        _songs   = [];

    var Artist = function(name, albums) {
        this.name = name;
        this.albums = albums || [];
    };

    Artist.prototype.songs = function() {
        var artistSongs = [];
        _.each(this.albums, function(album) {
            artistSongs = artistSongs.concat(album.songs);
        });
        return artistSongs.sort(compare);
    };

    var Album = function(name, artist, songs) {
        this.name = name;
        this.artist = artist;
        this.songs = songs || [];
    };

    var Song = function(id, name, album) {
        this.id = id;
        this.name = name;
        this.album = album;
    };

    Song.prototype.artist = function() {
        return this.album.artist;
    };

    function load(success) {
        $.getJSON(server + '/songs', function(data) {
            if (data.error && data.error == 'not ready') {
                setTimeout(load, 500, success); // TODO bug: never gets called
            } else {

                // Destroy caches
                _artists = [];
                _albums = [];
                _songs = [];

                _.each(data, function(dataAlbums, artistName) {
                    var artist = new Artist(artistName);
                    _artists.push(artist);

                    _.each(dataAlbums, function(dataSongs, albumName) {
                        var album = new Album(albumName, artist);
                        _albums.push(album);
                        artist.albums.push(album);

                        _.each(dataSongs, function(dataSong) {
                            var song = new Song(dataSong[1], dataSong[0], album);
                            _songs.push(song);
                            album.songs.push(song);
                        });
                    });

                    artist.albums = artist.albums.sort(compare);
                    library[artistName] = artist;
                });

                _artists = _artists.sort(compare);
                _albums = _albums.sort(compare);
                _songs = _songs.sort(compare);

                success();
            }
        });
    }

    function isEmpty() {
        return _.isEmpty(library);
    }

    function artists() {
        return _artists;
    }

    function albums() {
        return _albums;
    }

    function songs() {
        return _songs;
    }

    function clean(a) {
        a = a.name.trim().toLowerCase();
        a = a.replace(/^[^A-z0-9]/g, "");
        if (a.slice(0, 4) == "the ") a = a.slice(4);
        return a;
    }

    function compare(a, b) {
        a = clean(a);
        b = clean(b);

        if (a < b) {
            return -1;
        } else if (a > b) {
            return 1;
        } else {
            return 0;
        }
    }

    return {
        load: load,
        isEmpty: isEmpty,
        artists: artists,
        albums: albums,
        songs: songs
    };
}());

var Status = {
    data: {},
    callbacks: {},

    update: function() {
        var self = this;
        $.getJSON(server + '/status', function(data) {
            _.each(data, function(value, key) {
                self.set(key, value, false);
            });

            if (self.isUpdating) {
                setTimeout(function() {
                    self.update();
                }, 1500);
            }
        });
    },

    startUpdating: function() {
        this.isUpdating = true;
        this.update();
    },

    stopUpdating: function() {
        this.isUpdating = false;
    },

    set: function(key, value, silent) {
        if (!silent && value != this.data[key]) {
            this.trigger(key, value);
        }

        this.data[key] = value;
    },

    get: function(key) {
        return this.data[key];
    },

    on: function(event, fn) {
        if (!this.callbacks[event]) {
            this.callbacks[event] = [];
        }

        this.callbacks[event].push(fn);

        return this;
    },

    trigger: function(event, value) {
        _.each(this.callbacks[event], function(fn) {
            fn(event, value);
        });
    }
};

function renderView(library, container) {
    if (library.isEmpty()) {
        container.html('No songs to display');
        return;
    }

    var songlist = $(Mustache.render($('#library_template').html())),
        row = Mustache.compile($('#song_template').html());

    _.each(library.songs(), function(song) {
        songlist.append(row(song));
    });

    container.html(songlist);
}

function prevSong() {
    $.get(server + '/previous');
}

function nextSong() {
    $.get(server + '/next');
}

function togglePlay() {
    $.get(server + '/toggle_play');
    var state = Status.get('state') == 'paused' ? 'playing' : 'paused';
    Status.set('state', state);
}

$(function() {
    var $library = $('#library'),
        $np = $('#now_playing'),
        $volume = $('#volume'),
        $play = $('#play');

    Library.load(function() {
        $np.css('visibility', 'visible');
        renderView(Library, $library);
    });

    Status.on('artist', function(key, value) {
        $np.find('.artist').html(value);
    }).on('title', function(key, value) {
        $np.find('.title').html(value);
    }).on('volume', function(key, value) {
        $volume.val(value);
    }).on('state', function(key, value) {
        $play.removeClass('icon-pause icon-play');
        if (value == 'playing') {
            $play.addClass('icon-pause');
        } else {
            $play.addClass('icon-play');
        }
    }).startUpdating();

    $('#previous').on('mousedown', prevSong);
    $('#next').on('mousedown', nextSong);
    $play.on('mousedown', togglePlay);

    $(document).on('keydown', function(e) {
        switch (e.keyCode) {
            case 39:
                nextSong();
                break;
            case 37:
                prevSong();
                break;
            case 32:
                togglePlay();
                return false;
                break;
        }
    });

    $volume.on('change', _.debounce(
        _.bind(function() {
            $.get(server + '/volume/' + $(this).val());
        }, $volume)
    , 100));

    $library.on('mousedown', '.song', function() {
        var id = $(this).attr('data-id');
        $.get(server + '/play/' + id);
    });
});
