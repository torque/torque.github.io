# All implementations of this I've seen have been in javascript and
# designed for some heavy js framework such as jquery. I don't want to
# have to haul in jquery just for this, so let's do it just with built-
# in functions and maybe a little extra work.

# Benefits:
# - Coffeescript
# - CSS transitions and positioning
# - No jquery or similar needed
# - Generate all elements in constructor
# - This sweet list of benefits

# Detriments:
# - Spending time being mad at browsers
# - Have to do my own tech support

# Overall
# - Probably worth it?

class FootnoteBubble
	constructor: ( @footnote, @maxWidth, @articleNode ) ->
		@currentMax  = @maxWidth
		footnoteId   = @footnote.href.match(/^.+?#(.*)/)[1]
		footnoteText = document.getElementById(footnoteId).innerHTML

		@node = document.createElement 'div'
		@node.className = 'footnoteMagic invisible'
		@node.innerHTML = footnoteText
		@node.removeChild @node.querySelector 'a.reversefootnote'
		@nib = document.createElement 'div'
		@nib.className = 'nib'
		@node.appendChild @nib

		@shown = false
		@footnote.addEventListener 'click', @toggleState, no

	reflow: ( articleBounds ) ->
		@node.style.top = ''
		@node.style.left = ''
		@node.style.maxWidth = Math.min( @maxWidth, articleBounds.width ) + 'px'
		@width = @node.getBoundingClientRect( ).width
		@calculateEdges articleBounds

	calculateEdges: ( articleBounds ) ->
		anchorPosition = @footnote.getBoundingClientRect( )

		hOffset = anchorPosition.left + anchorPosition.width/2 - articleBounds.left
		vOffset = anchorPosition.top + anchorPosition.height - articleBounds.top

		left  = hOffset - @width/2
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

		@node.style.top  = vOffset + 0.5*Number( getComputedStyle( @node, "" ).fontSize.match( /(\d*(\.\d*)?)px/ )[1] ) + 'px'
		@node.style.left = left + 'px'

	toggleState: ( ev ) =>
		if @shown
			ev.target.style['z-index'] = 9
			@node.className = 'footnoteMagic outgoing'
			@shown = false
		else
			ev.target.style['z-index'] = 11
			@node.className = 'footnoteMagic incoming'
			@shown = true
			# make sure bubble is positioned correctly
			if @needsReflow
				@reflow @articleNode.getBoundingClientRect( )
				@needsReflow = false

		ev.preventDefault( )

FootnoteMagic = ( maxWidth ) ->
	footnotes     = document.querySelectorAll 'a.footnote'
	articleNode   = document.querySelector 'article.article'
	articleBounds = articleNode.getBoundingClientRect( )
	fragment      = document.createDocumentFragment( )
	bubbles       = []
	for footnote in footnotes
		footNode = new FootnoteBubble footnote, maxWidth, articleNode
		footNode.needsReflow = true
		fragment.appendChild footNode.node
		bubbles.push footNode

	articleNode.appendChild fragment

	oldResizeCb   = window.onresize
	reflowBubbles = ->
		articleBounds = articleNode.getBoundingClientRect( )
		for bubble in bubbles
			if bubble.shown
				bubble.reflow articleBounds
			else unless bubble.needsReflow
				bubble.needsReflow = true

		oldResizeCb?( )

	window.onresize = reflowBubbles

	# if mathjax was loaded, make sure bubbles reflow when it finishes.
	if (mj = window.MathJax)?
		mj.Hub.Register.StartupHook 'End', ->
			reflowBubbles( )

FootnoteMagic 700
