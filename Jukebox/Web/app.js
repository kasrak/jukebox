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

    $('#library').on('mousedown', 'a', function() {
        var id = $(this).attr('data-id');
        $.get(server + '/play/' + id);
    });

    $('#next').on('mousedown', function() {
        $.get(server + '/next');
    });

    $('#play').on('mousedown', function() {
        $.get(server + '/toggle_play');
    });
});
