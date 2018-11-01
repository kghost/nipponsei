$ ->
  album_base = "albums/"
  getParameterByName = (name) ->
    name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]")
    regex = new RegExp("[\\#&]" + name + "=([^&#]*)")
    results = regex.exec(location.hash)
    if (results)
      decodeURIComponent(results[1].replace(/\+/g, " "))

  $.fn.animateHighlight = (highlightColor, duration) ->
    highlightBg = highlightColor || "#FFFF9C"
    animateMs = duration || 1500
    originalBg = this.css "background-color"
    this.stop().css("background-color", highlightBg).animate
      backgroundColor: originalBg
    , animateMs

  save_playlist = if Storage
    (playlist) -> localStorage.playlist = JSON.stringify(_.map(playlist, (entry) ->
      song:
        name: entry.song.name
        album:
          name: entry.song.album.name))
  else
    () ->

  load_playlist = () ->
    return [] if not Storage or not localStorage?.playlist?
    try
      return JSON.parse(localStorage.playlist)
    catch
      return []

  get_album = (album, callback) ->
    if album.state == "none"
      album.state = "fetching"
      album.callbacks = [callback]
      $.ajax(encodeURI(album_base + album.name + ".json")).done (data) =>
        album.data = data
        album.data.songs = _.map(album.data.songs, (song) -> album: album, name: song)
        album.state = "done"
        _.each(album.callbacks, (cb) -> cb())
        album.callbacks = undefined
    else if album.state == "fetching"
      album.callbacks.push(callback)
    else if album.state == "done"
      callback()

  albumsPerPage = 8
  pagerShow = 7
  state =
    albums: []
    albums_data: {}
    page: 0
    played: []
    playlist:
      order: "normal"
      list: load_playlist()
    playing:
      is_playing: false
      song: null
    highlight:
      album: null
    playlist_update: ->
    pager_update: ->
    album_update: ->
    title_update: ->
      if state.playing.song != null
        song = state.playing.song
        navigator.mediaSession?.metadata = new MediaMetadata
          title: song.name
          album: song.album.name
          artwork: [{
            src: song.album.data.cover && album_base + song.album.data.location + '/' + song.album.data.cover || "cover.png"
          }]
        if state.playing.is_playing
          document.title = "Nipponsei ▶ #{song.name} of #{song.album.name}"
        else
          document.title = "Nipponsei ❚❚ #{song.name} of #{song.album.name}"
      else
        navigator.mediaSession?.metadata = null
        document.title = "Nipponsei"

  navigator.mediaSession?.setActionHandler('seekbackward', -> player.jPlayer("play", player.data('jPlayer').status.currentTime - 10))
  navigator.mediaSession?.setActionHandler('seekforward', -> player.jPlayer("play", player.data('jPlayer').status.currentTime + 10))
  navigator.mediaSession?.setActionHandler('previoustrack', -> queue_play(state.played.pop()))
  navigator.mediaSession?.setActionHandler('nexttrack', -> play_next(state.playing.song, false))

  {table, thead, tbody, th, button, span, tr, td, div, ul, li, td, hr, a, h4, img} = React.DOM

  Playlist = React.createFactory React.createClass
    componentDidMount: ->
      state.playlist_update = @forceUpdate.bind(@)

    setOrder: (order) ->
      state.playlist.order = order
      @forceUpdate()

    removeSong: (entry) ->
      play_next(entry.song, true) if state.playing.song == entry.song
      state.playlist.list = _.without(state.playlist.list, entry)
      save_playlist(state.playlist.list)
      state.pager_update()
      state.album_update()
      @forceUpdate()
      false

    render: ->
      table className: "table table-striped",
        thead null,
          tr null,
            th colSpan: 2,
              div className: "btn-group",
                span className: "glyphicon glyphicon-list"
              div className: "btn-group pull-right",
                button type: "button", className: "btn btn-default btn-sm" + (state.playlist.order == "normal" && " active" || ""), onClick: @setOrder.bind(null, "normal"),
                  span className: "glyphicon glyphicon-arrow-down"
                button type: "button", className: "btn btn-default btn-sm" + (state.playlist.order == "repeat" && " active" || ""), onClick: @setOrder.bind(null, "repeat"),
                  span className: "glyphicon glyphicon-repeat"
                button type: "button", className: "btn btn-default btn-sm" + (state.playlist.order == "random" && " active" || ""), onClick: @setOrder.bind(null, "random"),
                  span className: "glyphicon glyphicon-random"
        tbody null,
          if state.playlist.list.length > 0
            _.map(state.playlist.list, (entry, index) =>
              i = if not entry.resolved
                if not entry.fetch
                  entry.fetch = true
                  if not (entry.song.album.name of state.albums_data)
                    state.albums_data[entry.song.album.name] = {state: "none", name: entry.song.album.name}
                  album = state.albums_data[entry.song.album.name]
                  get_album(album, () =>
                    song = _.find(album.data.songs, (song) -> song.name == entry.song.name)
                    if song
                      entry.resolved = true
                      entry.song = song
                    else
                      entry.missing = true
                    @forceUpdate())

                key: entry.song.album.name + '/' + entry.song.name
                className: entry.missing && "danger" || "warning"
              else
                key: entry.song.album.name + '/' + entry.song.name
                className: state.playing.is_playing && state.playing.song == entry.song && "info" || ""
                onClick: play.bind(null, entry.song)
              tr i,
                td null,
                  div null, entry.song.album.name
                  ul style: {marginBottom: 0},
                    li null, entry.song.name
                td style: {verticalAlign: "middle"},
                  button type: "button", className: "btn btn-sm", onClick: @removeSong.bind(null, entry),
                    span className: "glyphicon glyphicon-minus")
          else
            tr null,
              td colSpan: 2,
                div null,
                  "Empty Playlist"

  React.render(Playlist(), $("#playlist")[0])

  Pager = React.createFactory React.createClass
    componentDidMount: ->
      state.pager_update = @forceUpdate.bind(@)

    prev: () ->
      if state.page > 0
        state.page -= 1
        @forceUpdate()
        state.album_update()

    next: () ->
      if state.page + 1 < Math.ceil(state.albums.length / albumsPerPage)
        state.page += 1
        @forceUpdate()
        state.album_update()

    pageTo: (page) ->
      state.page = page
      @forceUpdate()
      state.album_update()

    scroll: (album) ->
      if album.domId
        $('html, body').animate(
          scrollTop: $('#'+album.domId).offset().top,
          500)

    render: ->
      total_page = Math.ceil(state.albums.length / albumsPerPage)
      currentpage = state.page
      low = Math.max(0, currentpage - (pagerShow - Math.min(Math.ceil(pagerShow/2), total_page - currentpage)))
      high = Math.min(total_page, currentpage + (pagerShow - Math.min(Math.floor(pagerShow/2), currentpage)))
      div null,
        div className: "list-group",
          _.map(state.albums.slice(state.page*albumsPerPage, state.page*albumsPerPage + albumsPerPage), (album_name) =>
            album = state.albums_data[album_name]
            a key: album.name, className: "list-group-item" + (state.highlight.album == album && " list-group-item-success" || (state.playing.is_playing && state.playing.song.album == album && " list-group-item-info" || (_.any(state.playlist.list, (entry) -> entry.song.album == album) && " list-group-item-warning" || ""))), onClick: @scroll.bind(null, album),
              album.name)
          div className: "list-group-item text-center",
            ul className: "pagination pagination-sm", style: {marginBottom: 0, marginTop: 0},
              li className: state.page == 0 && "disabled",
                a onClick: @prev,
                  span null,
                    "«"
              _.map(_.range(low, high), (page) =>
                li key: page, className: state.page == page && "active",
                  a onClick: @pageTo.bind(null, page),
                    span null,
                      page + 1)
              li className: state.page + 1 == total_page && "disabled",
                a onClick: @next,
                  span null,
                    "»"

  React.render(Pager(), $("#pager")[0])

  Album = React.createFactory React.createClass
    componentDidMount: ->
      state.album_update = @forceUpdate.bind(@)

    render: ->
      range = state.albums.slice(state.page*albumsPerPage, state.page*albumsPerPage + albumsPerPage)
      div null,
        if range.length > 0
          _.reduce(_.map(range, (album_name) =>
            album = state.albums_data[album_name]
            if album.state == "none"
              get_album(album, @forceUpdate.bind(@))

            album.domId = _.uniqueId()
            if album.state == "fetching"
              div key: album.name, id: album.domId, className: "container-fluid",
                div className: "col-xs-12 col-sm-12 col-md-3",
                  a className: "thumbnail",
                    img src: "cover.png"
                div className: "col-xs-12 col-sm-12 col-md-9",
                  h4 null,
                    "Loading " + album.name
            else if album.state == "done"
              div key: album.name, id: album.domId, className: "container-fluid",
                div className: "col-xs-12 col-sm-12 col-md-3",
                  a className: "thumbnail",
                    img src: album.data.cover && album_base + album.data.location + '/' + album.data.cover || "cover.png"
                div className: "col-xs-12 col-sm-12 col-md-9",
                  h4 null,
                    album.data.name
                  table className: "table table-hover",
                    tbody null,
                      _.map(album.data.songs, (song) =>
                        tr key: song.name, className: state.playing.is_playing && state.playing.song == song && "info" || (_.any(state.playlist.list, (entry) -> entry.song == song) && "warning" || ""),
                          td style: {width: "100%", verticalAlign: "middle"}, onClick: queue_play.bind(null, song),
                            a null,
                              song.name
                          td null,
                            span className: "glyphicon glyphicon-plus", onClick: =>
                              queue(song)
                              @forceUpdate()),
                  if album.data.jackets.length > 0
                    jackets = _.map(album.data.jackets, (jacket) -> album_base + album.data.location + '/' + jacket)
                    div null,
                      _.map(album.data.jackets, (jacket, index) ->
                        a key: jacket, className: "thumbnail", style: {display: "inline-block"}, onClick: (-> blueimp.Gallery(jackets, {index: index})),
                          img src: album_base + album.data.location + '/tn/' + jacket)
                  else
                    null)

            (result, next) -> result.length > 0 && result.concat([hr(key: result.length), next]) || [next],
            [])
        else
          []

  React.render(Album(), $("#albums")[0])

  queue = (song) ->
    if not _.find(state.playlist.list, (entry) -> entry.song == song)
      state.playlist.list.push(resolved: true, song: song)
      save_playlist(state.playlist.list)
      state.playlist_update()
      state.pager_update()

  queue_play = (song) ->
    queue(song)
    play(song)

  play_next = (last, remove) ->
    list = _.filter(state.playlist.list, (entry) -> entry.resolved)
    if state.playlist.order == "random"
      if list.length > 1
        loop
          next = _.sample(list).song
          break if last != next
      else
        if remove
          next = null
        else
          next = last
    else
      if remove && list.length == 1
        next = null
      else
        n = _.findIndex(list, (entry) -> entry.song == last)
        if n < 0
          next = null
        else
          if n + 1 == list.length
            if state.playlist.order == "normal"
              next = null
            else
              next = list[0].song
          else
            next = list[n + 1].song
    if next
      play(next)
    else
      stop()

  stop = () ->
    state.played.push(state.playing.song)
    state.playing.song = null
    player.jPlayer("clearMedia")

  play = (song) ->
    state.played.push(state.playing.song)
    state.playing.song = song
    player.jPlayer("setMedia",
      mp3: album_base + song.album.data.location + '/' + song.name
    ).jPlayer("play")

  player = $("#jquery_jplayer_1")
  player.jPlayer(
    swfPath: "https://cdnjs.cloudflare.com/ajax/libs/jplayer/2.9.2/jplayer/jquery.jplayer.swf"
    supplied: "mp3"
    useStateClassSkin: true
    size:
      width: "100%"
    volume: do -> if (v = localStorage?.getItem("volume"))
      JSON.parse(v)
    else
      0.5
    play: ->
      state.playing.is_playing = true
      state.title_update()
      state.playlist_update()
      state.pager_update()
      state.album_update()
    pause: ->
      state.playing.is_playing = false
      state.title_update()
      state.playlist_update()
      state.pager_update()
      state.album_update()
    ended: ->
      state.playing.is_playing = false
      play_next(state.playing.song, false)
      state.title_update()
      state.playlist_update()
      state.pager_update()
      state.album_update()
    repeat: ->
    volumechange: (e) -> localStorage?.setItem("volume", JSON.stringify(e.jPlayer.options.volume))
  )

  $.ajax(album_base + "list.txt").done (list) ->
    lines = list.replace(/\r\n/g, "\n").split("\n")
    lines.length = lines.length - 1 # last is empty
    state.albums = lines.reverse()
    _.each(state.albums, (album_name) ->
      if not (album_name of state.albums_data)
        state.albums_data[album_name] = {state: "none", name: album_name})
    state.pager_update()
    state.album_update()

    $('#search').typeahead(hint: true, highlight: true, minLength: 1,
      name: 'search'
      display: (s) -> s
      source: (query, cb) ->
        q = new RegExp(query, "i")
        cb(_.chain(state.albums).filter((album_name) -> album_name.search(q) >= 0).head(10).value()))

    $('#search').bind('typeahead:selected', (obj, datum, da) ->
      state.highlight.album = datum
      state.page = Math.floor(_.indexOf(state.albums, datum) / albumsPerPage)
      state.pager_update()
      state.album_update())
