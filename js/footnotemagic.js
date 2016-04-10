(function() {
  var FootnoteBubble, FootnoteMagic,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  FootnoteBubble = (function() {
    function FootnoteBubble(footnote, maxWidth, articleNode) {
      var footnoteId, footnoteText;
      this.footnote = footnote;
      this.maxWidth = maxWidth;
      this.articleNode = articleNode;
      this.toggleState = __bind(this.toggleState, this);
      this.currentMax = this.maxWidth;
      footnoteId = this.footnote.href.match(/^.+?#(.*)/)[1];
      footnoteText = document.getElementById(footnoteId).innerHTML;
      this.node = document.createElement('div');
      this.node.className = 'footnoteMagic invisible';
      this.node.innerHTML = footnoteText;
      this.node.removeChild(this.node.querySelector('a.reversefootnote'));
      this.nib = document.createElement('div');
      this.nib.className = 'nib';
      this.node.appendChild(this.nib);
      this.shown = false;
      this.footnote.addEventListener('click', this.toggleState, false);
    }

    FootnoteBubble.prototype.reflow = function(articleBounds) {
      this.node.style.top = '';
      this.node.style.left = '';
      this.node.style.maxWidth = Math.min(this.maxWidth, articleBounds.width) + 'px';
      this.width = this.node.getBoundingClientRect().width;
      return this.calculateEdges(articleBounds);
    };

    FootnoteBubble.prototype.calculateEdges = function(articleBounds) {
      var anchorPosition, hOffset, left, right, shift, vOffset;
      anchorPosition = this.footnote.getBoundingClientRect();
      hOffset = anchorPosition.left + anchorPosition.width / 2 - articleBounds.left;
      vOffset = anchorPosition.top + anchorPosition.height - articleBounds.top;
      left = hOffset - this.width / 2;
      right = left + this.width;
      shift = 0;
      if (right > articleBounds.width) {
        shift = right - articleBounds.width;
      } else if (left < 0) {
        shift = left;
      }
      left -= shift;
      if (shift) {
        this.nib.style.left = Math.min(this.width / 2 + shift, this.width - 10) + 'px';
      } else {
        this.nib.style.left = '50%';
      }
      this.node.style.top = vOffset + 0.5 * Number(getComputedStyle(this.node, "").fontSize.match(/(\d*(\.\d*)?)px/)[1]) + 'px';
      return this.node.style.left = left + 'px';
    };

    FootnoteBubble.prototype.toggleState = function(ev) {
      if (this.shown) {
        ev.target.style['z-index'] = 9;
        this.node.className = 'footnoteMagic outgoing';
        this.shown = false;
      } else {
        ev.target.style['z-index'] = 11;
        this.node.className = 'footnoteMagic incoming';
        this.shown = true;
        if (this.needsReflow) {
          this.reflow(this.articleNode.getBoundingClientRect());
          this.needsReflow = false;
        }
      }
      return ev.preventDefault();
    };

    return FootnoteBubble;

  })();

  FootnoteMagic = function(maxWidth) {
    var articleBounds, articleNode, bubbles, footNode, footnote, footnotes, fragment, mj, oldResizeCb, reflowBubbles, _i, _len;
    footnotes = document.querySelectorAll('a.footnote');
    articleNode = document.querySelector('article.article');
    articleBounds = articleNode.getBoundingClientRect();
    fragment = document.createDocumentFragment();
    bubbles = [];
    for (_i = 0, _len = footnotes.length; _i < _len; _i++) {
      footnote = footnotes[_i];
      footNode = new FootnoteBubble(footnote, maxWidth, articleNode);
      footNode.needsReflow = true;
      fragment.appendChild(footNode.node);
      bubbles.push(footNode);
    }
    articleNode.appendChild(fragment);
    oldResizeCb = window.onresize;
    reflowBubbles = function() {
      var bubble, _j, _len1;
      articleBounds = articleNode.getBoundingClientRect();
      for (_j = 0, _len1 = bubbles.length; _j < _len1; _j++) {
        bubble = bubbles[_j];
        if (bubble.shown) {
          bubble.reflow(articleBounds);
        } else if (!bubble.needsReflow) {
          bubble.needsReflow = true;
        }
      }
      return typeof oldResizeCb === "function" ? oldResizeCb() : void 0;
    };
    window.onresize = reflowBubbles;
    if ((mj = window.MathJax) != null) {
      return mj.Hub.Register.StartupHook('End', function() {
        return reflowBubbles();
      });
    }
  };

  FootnoteMagic(700);

}).call(this);
