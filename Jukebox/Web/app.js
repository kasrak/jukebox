var server = '',
    library = null;

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
    if (library === null) return;

    var artists = Object.keys(library).sort(),
        $library = $('#library');

    $library.html('');

    for (var i in artists) {
        var artist = artists[i],
            albums = Object.keys(library[artist]).sort();

        $library.append('<h2>' + artist + '</h2>');
        
        for (var j in albums) {
            var album = albums[j],
                songs = library[artist][album];

            $library.append('<h3>' + album + '</h3>');
            
            for (var k in songs) {
                var song = songs[k];
                $library.append('<a data-id="' + song[1] + '">' + song[0] + '</a>');
            }
        }
    }
}

$(function() {
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
});
