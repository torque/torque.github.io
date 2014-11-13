# All implementations of this I've seen have been in javascript and
# designed for some heavy js framework such as jquery. I don't want to
# have to haul in jquery just for this, so let's do it just with built-
# in functions and maybe a little extra work.

# Benefits:
# - Coffeescript
# - CSS transitions
# - No jquery or similar needed
# - Generate all elements in constructor
# - This sweet list of benefits

# Detriments:
# - Spending time being mad at browsers
# - Have to do my own tech support

# Overall
# - Probably worth it?

marginSize = 30

class FootNoteHoverMagic

	constructor: ( @width ) ->
		@viewWidth = window.innerWidth - marginSize
		@originalWidth = @width - marginSize
		@width = Math.min @viewWidth, @originalWidth
		@hoverDivs = { }
		@contentWrap = document.querySelector ".content-wrap"

		return unless @contentWrap

		footnotes = document.querySelectorAll "a.footnote"
		for footnote in footnotes
			footnote.removeEventListener "mouseover", @mouseOverCb, false
			footnote.addEventListener "mouseover", @mouseOverCb, false

			# footnote.href contains the full link, which includes the current
			# page base url. Matching the id is pretty much the simplest way
			# to do this, as far as I can tell.
			footnoteId = footnote.href.match(/^.+?#(.*)/)[1]
			footnoteText = document.getElementById(footnoteId).innerHTML
			hoverDiv = document.createElement 'div'
			hoverDiv.className = "footnotemagic"
			hoverDiv.innerHTML = footnoteText

			# Remove linkback
			hoverDiv.removeChild hoverDiv.querySelector 'a.reversefootnote'

			hoverDiv.style.width = @width + 'px'

			# Append our footnote hover div to the body. CSS provides
			# display:none.
			document.body.appendChild hoverDiv

			# Store a reference to the node for later access.
			@hoverDivs[footnoteId] = hoverDiv

	mouseOverCb: ( ev ) =>
		footnoteLabel = ev.target
		footnoteId = footnoteLabel.href.match(/^.+?#(.*)/)[1]
		hoverDiv = @hoverDivs[footnoteId]

		viewOffset = footnoteLabel.getBoundingClientRect( )

		# Because we cannot have nice things, Safari reports scrollTop on
		# body and FireFox reports it on documentElement.
		vertComp = document.body.scrollTop or document.documentElement.scrollTop
		horzComp = document.body.scrollLeft or document.documentElement.scrollLeft
		# Hardcoded 5px offset for top padding so footnote div baseline
		# lines up with normal text baseline. This should probably not be
		# hardcoded.
		top = viewOffset.top + vertComp - 5
		left = viewOffset.left + horzComp

		viewWidth = window.innerWidth - marginSize

		# viewwidth has changed and needs updating
		if viewWidth isnt @viewWidth
			@viewWidth = viewWidth
			@width = Math.min viewWidth, @originalWidth
			hoverDiv.style.width = @width + 'px'

		# Check if the window is less than @width pixels wide. There should
		# be no margin in this case.
		if viewWidth is @width
			rightBound = viewWidth
		else
			rightBound = 0.5*(viewWidth + @contentWrap.offsetWidth) + horzComp

		left = Math.min left, rightBound - @width

		hoverDiv.style.top = top + 'px'
		hoverDiv.style.left = left + 'px'
		hoverDiv.style.display = "block"
		hoverDiv.removeEventListener "mouseout", @mouseOut, false
		hoverDiv.addEventListener "mouseout", @mouseOut, false

	mouseOut: ( ev ) =>
		hoverDiv = ev.target
		# An event listener for transition end might be technically better
		# than a timer, but it suffers from a couple of key issues: The
		# mouse reentering before the fadeout is done, and mediocre
		# cross-browser support.

		@mouseOutTimer = setTimeout ->
			hoverDiv.removeEventListener "mouseover", @mouseRecover, false
			hoverDiv.removeEventListener "mouseout", @mouseOut, false
			hoverDiv.style.display = "none"
		, 251

		hoverDiv.removeEventListener "mouseover", @mouseRecover, false
		hoverDiv.addEventListener "mouseover", @mouseRecover, false

	mouseRecover: (ev) =>
		clearTimeout @mouseOutTimer

new FootNoteHoverMagic 500
