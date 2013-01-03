var server = '',
    library = null,
    $library = null;

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

function getStatus() {
    $.getJSON(server + '/status', function(data) {
        var $np = $('#now_playing'),
            $volume = $('#volume'),
            $play = $('#play');

        $np.find('.title').html(data.title);
        $np.find('.artist').html(data.artist);

        $volume.val(data.volume);

        if (data.state == 'playing') {
            $play.html('Pause');
        } else if (data.state == 'paused') {
            $play.html('Play');
        }

        setTimeout(getStatus, 1500);
    });
}

function debounce(fn, wait, context) {
    var timer;
    return function() {
        if (timer) {
            clearTimeout(timer);
        }

        timer = setTimeout(function() {
            fn.apply(context, arguments)
        }, wait);
    };
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
            albums = Object.keys(library[artist]).sort();

        $artist = $('<div class="artist">');
        $artist.append('<br><a class="artist">' + artist + '</a>');
        
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

    getSongs();
    getStatus();

    $('#library').on('mousedown', 'a', function() {
        var id = $(this).attr('data-id');
        $.get(server + '/play/' + id);
    });

    $('#next').on('mousedown', function() {
        $.get(server + '/next');
    });

    $('#play').on('mousedown', function() {
        $.get(server + '/toggle_play');

        var $this = $(this);
        if ($this.html() == 'Play') {
            $this.html('Pause');
        } else if ($this.html() == 'Pause') {
            $this.html('Play');
        }
    });

    $('#volume').on('change', debounce(function() {
        $.get(server + '/volume/' + $(this).val());
    }, 100, $('#volume')));

    $library.on('click', 'a.artist', function() {
        $albums = $(this).parents('.artist').children('.albums');
        if ($albums.css('display') !== 'none') {
            $albums.hide();
        } else {
            $albums.show();
        }
    });
});
