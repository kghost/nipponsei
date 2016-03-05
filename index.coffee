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

  albumsPerPage = 8
  pagerShow = 7
  state =
    albums: []
    page: 0
    playlist:
      order: "normal"
      list: []
    playing:
      is_playing: false
      entry: null
    highlight:
      album: null
    playlist_update: =>
    pager_update: =>
    album_update: =>

  {table, thead, tbody, th, button, span, tr, td, div, ul, li, td, hr, a, h4, img} = React.DOM

  Playlist = React.createFactory React.createClass
    componentDidMount: ->
      state.playlist_update = @forceUpdate.bind(@)

    setOrder: (order) ->
      state.playlist.order = order
      @forceUpdate()

    removeSong: (entry) ->
      if state.playing.entry == entry
        play_next(entry, true)
      state.playlist.list = _.without(state.playlist.list, entry)
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
              tr key: entry.album.name + '/' + entry.name, className: state.playing.is_playing && state.playing.entry == entry && "info" || "", onClick: play.bind(null, entry),
                td null,
                  div null, entry.album.name
                  ul style: {marginBottom: 0},
                    li null, entry.name
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
          _.map(state.albums.slice(state.page*albumsPerPage, state.page*albumsPerPage + albumsPerPage), (album) =>
            a key: album.name, className: "list-group-item" + (state.highlight.album == album && " list-group-item-success" || (state.playing.is_playing && state.playing.entry.album == album && " list-group-item-info" || (_.any(state.playlist.list, (entry) -> entry.album == album) && " list-group-item-warning" || ""))), onClick: @scroll.bind(null, album),
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
          _.reduce(_.map(range, (album) =>
            if album.state == "none"
              album.state = "fetching"
              $.ajax(encodeURI(album_base + album.name + ".json")).done (data) =>
                album.data = data
                album.data.songs = _.map(album.data.songs, (song) -> album: album, name: song)
                album.state = "done"
                @forceUpdate()

            album.domId = _.uniqueId()
            if album.state == "fetching"
              div key: album.name, id: album.domId, className: "container-fluid",
                div className: "col-xs-12 col-sm-12 col-md-3",
                  a className: "thumbnail",
                    img src: "cover.png"
                div className: "col-xs-12 col-sm-12 col-md-9",
                  h4 null,
                    "Loading " + album.name
            else if album.state = "done"
              div key: album.name, id: album.domId, className: "container-fluid",
                div className: "col-xs-12 col-sm-12 col-md-3",
                  a className: "thumbnail",
                    img src: album.data.cover && album_base + album.data.location + '/' + album.data.cover || "cover.png"
                div className: "col-xs-12 col-sm-12 col-md-9",
                  h4 null,
                    album.data.name
                  table className: "table table-hover",
                    tbody null,
                      _.map(album.data.songs, (song) ->
                        tr key: song.name, className: state.playing.is_playing && state.playing.entry == song && "info" || (_.any(state.playlist.list, (entry) -> entry == song) && "warning" || ""),
                          td style: {width: "100%", verticalAlign: "middle"}, onClick: queue_play.bind(null, song),
                            a null,
                              song.name
                          td null,
                            span className: "glyphicon glyphicon-plus", onClick: queue.bind(null, song)),
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

  queue = (entry) ->
    if not _.contains(state.playlist.list, entry)
      state.playlist.list.push(entry)
      state.playlist_update()

  queue_play = (entry) ->
    queue(entry)
    play(entry)

  play_next = (last, remove) ->
    if state.playlist.order == "random"
      if state.playlist.list.length > 1
        loop
          next = _.sample(state.playlist.list)
          break if last != next
      else
        if remove
          next = null
        else
          next = last
    else
      if remove && state.playlist.list.length == 1
        next = null
      else
        n = _.indexOf(state.playlist.list, last)
        if n < 0
          next = null
        else
          if n + 1 == state.playlist.list.length
            if state.playlist.order == "normal"
              next = null
            else
              next = state.playlist.list[0]
          else
            next = state.playlist.list[n + 1]
    if next
      play(next)
    else
      player.jPlayer("clearMedia")

  play = (entry) ->
    state.playing.entry = entry
    player.jPlayer("setMedia",
      mp3: album_base + entry.album.data.location + '/' + entry.name
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
      state.playlist_update()
      state.pager_update()
      state.album_update()
    pause: ->
      state.playing.is_playing = false
      state.playlist_update()
      state.pager_update()
      state.album_update()
    ended: ->
      state.playing.is_playing = false
      last = state.playing.entry
      state.playing.entry = null
      state.playlist_update()
      state.pager_update()
      state.album_update()
      play_next(last, false)
    repeat: ->
    volumechange: (e) -> localStorage?.setItem("volume", JSON.stringify(e.jPlayer.options.volume))
  )

  $.ajax(album_base + "list.txt").done (list) ->
    lines = list.replace(/\r\n/g, "\n").split("\n")
    lines.length = lines.length - 1 # last is empty
    state.albums = _.map(lines.reverse(), (album) -> state: "none", name: album)
    state.pager_update()
    state.album_update()

    $('#search').typeahead(hint: true, highlight: true, minLength: 1,
      name: 'search'
      displayKey: "name"
      source: (query, cb) ->
        q = new RegExp(query, "i")
        cb(_.chain(state.albums).filter((album) -> album.name.search(q) >= 0).head(10).value()))

    $('#search').bind('typeahead:selected', (obj, datum, da) ->
      state.highlight.album = datum
      state.page = Math.floor(_.indexOf(state.albums, datum) / albumsPerPage)
      state.pager_update()
      state.album_update())
