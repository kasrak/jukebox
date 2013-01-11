'use strict';

var server = '';

var Library = (function() {
    var library = {},
        _artists = null,
        _songs = null;


    function load(success) {
        $.getJSON(server + '/songs', function(data, status) {
            if (data.error && data.error == 'not ready') {
                setTimeout(load, 500);
            } else {
                library = data;

                // Destroy caches
                _artists = null;
                _songs = null;

                success();
            }
        });
    }

    function isEmpty() {
        return artists().length === 0;
    }

    function artists() {
        if (!_artists) {
            _artists = Object.keys(library).sort(stringCompare);
        }

        return _artists;
    }

    function albums(artist) {
        return (library[artist]) ? Object.keys(library[artist]).sort(stringCompare) : [];
    }

    function songs(artist, album) {
        if (!artist) {
            // all songs
            if (!_songs) {
                _songs = [];
                _.each(artists(), function(artist) {
                    _songs = _songs.concat(songs(artist));
                });

                _songs = _songs.sort(songCompare);
            }

            return _songs;
        } else if (!album) {
            // all of artist's songs
            var artistSongs = [];
            _.each(library[artist], function(albumSongs) {
                artistSongs = artistSongs.concat(albumSongs);
            });
            return artistSongs;
        } else {
            return (library[artist]) ? library[artist][album].sort(songCompare) : [];
        }
    }

    function songCompare(a, b) {
        return stringCompare(a[0], b[0]);
    }

    function stringCompare(a, b) {
        a = a.trim().toLowerCase();
        b = b.trim().toLowerCase();

        if (a.slice(0, 4) == "the ") a = a.slice(4);
        if (b.slice(0, 4) == "the ") b = b.slice(4);

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

function renderArtistsView(library, container) {
    if (library.isEmpty()) {
        container.html('No songs to display');
        return;
    }

    container.html('');

    _.each(library.artists(), function(artist) {
        var $artist = $('<div class="artist">').html('<a class="artist">' + artist + '</a>'),
            $albums = $('<div class="albums">');
        
        _.each(library.albums(artist), function(album) {
            $albums.append('<h3>' + album + '</h3>');
            
            _.each(library.songs(artist, album), function(song) {
                $albums.append('<a class="song" data-id="' + song[1] + '">' + song[0] + '</a>');
            });
        });

        $artist.append($albums);
        container.append($artist);
    });

    $('div.albums').hide();
}

$(function() {
    var $library = $('#library'),
        $np = $('#now_playing'),
        $volume = $('#volume'),
        $play = $('#play');

    Library.load(function() {
        renderArtistsView(Library, $library);
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

    $('#previous').on('mousedown', function() {
        $.get(server + '/previous');
    });

    $('#next').on('mousedown', function() {
        $.get(server + '/next');
    });

    $play.on('mousedown', function() {
        $.get(server + '/toggle_play');
        var state = Status.get('state') == 'paused' ? 'playing' : 'paused';
        Status.set('state', state);
    });

    $volume.on('change', _.debounce(
        _.bind(function() {
            $.get(server + '/volume/' + $(this).val());
        }, $volume)
    , 100));

    $library.on('click', 'a.artist', function() {
        $(this).parents('.artist').children('.albums').toggle();
    }).on('mousedown', 'a.song', function() {
        var id = $(this).attr('data-id');
        $.get(server + '/play/' + id);
    });

});
