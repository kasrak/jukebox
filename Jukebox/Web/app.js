"use strict";

var $library, library; // xxx 

var server = '';

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
                    Status.update();
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

function getSongs() {
    $.getJSON(server + '/songs', function(data, status) {
        if (status == 'success') {
            if (data.error && data.error == 'not ready') {
                setTimeout(getSongs, 500);
            } else {
                library = data;
                renderLibrary();
            }
        } else {
            setTimeout(getSongs, 1000);
        }
    });
}

function renderLibrary() {
    if (library === null) {
        $library.html('No songs to display');
        return;
    }

    $library.html('');
    var artists = Object.keys(library).sort();

    for (var i in artists) {
        var artist = artists[i],
            albums = Object.keys(library[artist]).sort(),
            $artist = $('<div class="artist">').html('<br><a class="artist">' + artist + '</a>'),
            $albums = $('<div class="albums">');
        
        for (var j in albums) {
            var album = albums[j],
                songs = library[artist][album];

            $albums.append('<h3>' + album + '</h3>');
            
            for (var k in songs) {
                var song = songs[k];
                $albums.append('<a class="song" data-id="' + song[1] + '">' + song[0] + '</a><br>');
            }
        }

        $artist.append($albums);
        $library.append($artist);
    }
    $('div.albums').hide();
}

$(function() {
    $library = $('#library');
    var $np = $('#now_playing'),
        $volume = $('#volume'),
        $play = $('#play');

    getSongs();

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
