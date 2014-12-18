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

class FootnoteBubble
	constructor: ( @footnote, @maxWidth, articleBounds ) ->
		@currentMax = @maxWidth
		footnoteId = @footnote.href.match(/^.+?#(.*)/)[1]
		footnoteText = document.getElementById(footnoteId).innerHTML

		@element = document.createElement 'div'
		@element.innerHTML = footnoteText
		@element.removeChild @element.querySelector 'a.reversefootnote'
		@nib = document.createElement 'div'
		@nib.className = 'nib'
		@element.appendChild @nib

		@shown = true
		document.querySelector( 'article.article' ).appendChild @element
		@reflow articleBounds
		@shown = false

		@footnote.onclick = @toggleState

	reflow: ( articleBounds ) ->
		unless @shown
			@element.className = 'footnoteMagic'

		@element.style.top = ''
		@element.style.left = ''
		@element.style['max-width'] = Math.min( @maxWidth, articleBounds.width ) + 'px'
		@width = @element.getBoundingClientRect( ).width
		unless @shown
			@element.className = 'footnoteMagic invisible'
		@calculateEdges articleBounds

	calculateEdges: ( articleBounds ) ->
		anchorPosition = @footnote.getBoundingClientRect( )

		hOffset = anchorPosition.left + anchorPosition.width/2 - articleBounds.left
		vOffset = anchorPosition.top + anchorPosition.height - articleBounds.top

		left = hOffset - @width/2
		right = left + @width
		shift = 0

		if right > articleBounds.width
			shift = right - articleBounds.width
		else if left < 0
			shift = left

		left -= shift

		if shift
			@nib.style.left = Math.min( @width/2 + shift, @width-10 ) + 'px'
		else
			@nib.style.left = '50%'

		@element.style.top = vOffset + 0.5*Number(getComputedStyle(@element, "").fontSize.match(/(\d*(\.\d*)?)px/)[1]) + 'px'
		@element.style.left = left + 'px'

	toggleState: ( ev ) =>
		if @shown
			@element.className = 'footnoteMagic outgoing'
			@shown = false
		else
			@element.className = 'footnoteMagic incoming'
			@shown = true

		return false

class FootnoteMagic
	constructor: ( maxWidth ) ->
		@bubbles = []

		footnotes = document.querySelectorAll "a.footnote"
		articleBounds = document.querySelector('article.article').getBoundingClientRect( )
		for footnote in footnotes
			@bubbles.push new FootnoteBubble footnote, maxWidth, articleBounds

		window.MathJax?.Hub.Register.StartupHook 'End', =>
			@reflowBubbles( )

		@oldResizeCb = window.onresize

		window.onresize = @reflowBubbles

	reflowBubbles: =>
		clearTimeout @reflowTimer
		@reflowTimer = setTimeout =>
			articleBounds = document.querySelector('article.article').getBoundingClientRect( )
			for bubble in @bubbles
				bubble.reflow articleBounds
		, 100

		oldResizeCb?( )

new FootnoteMagic 700
