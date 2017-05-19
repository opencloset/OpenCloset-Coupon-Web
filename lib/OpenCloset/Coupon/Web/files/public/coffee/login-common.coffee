$ ->
  #
  # http://www.w3schools.com/js/js_cookies.asp
  #
  setCookie = (cname, cvalue, exdays) ->
    d = new Date()
    d.setTime(d.getTime() + (exdays*24*60*60*1000))
    expires = "expires="+d.toUTCString()
    document.cookie = cname + "=" + cvalue + "; " + expires
  getCookie = (cname) ->
    name = cname + "="
    ca = document.cookie.split(";")
    for c in ca
        while c.charAt(0) == " "
            c = c.substring(1)
        if c.indexOf(name) == 0
            return c.substring(name.length, c.length)
    return ""

  if getCookie("accept-cookie") == ""
    $("#cookie-header").show()
    $("#cookie-agree").on "click", (e) ->
      setCookie( "accept-cookie", "gotit", 3650 )
      $("#cookie-header").hide()
