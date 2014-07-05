package openfl.display; #if !flash


import haxe.EnumFlags;
import lime.geom.Matrix4;
import lime.graphics.CanvasRenderContext;
import lime.graphics.DOMRenderContext;
import lime.graphics.GLRenderContext;
import lime.graphics.RenderContext;
import lime.utils.GLUtils;
import openfl.events.Event;
import openfl.events.EventPhase;
import openfl.events.FocusEvent;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.ui.Keyboard;
import openfl.ui.KeyLocation;

#if js
import js.html.CanvasElement;
import js.html.DivElement;
import js.html.Element;
import js.html.HtmlElement;
import js.Browser;
#end


@:access(openfl.events.Event)
class Stage extends Sprite {
	
	
	public var align:StageAlign;
	public var allowsFullScreen:Bool;
	public var color (get, set):Int;
	public var displayState(default, set):StageDisplayState;
	public var focus (get, set):InteractiveObject;
	public var frameRate:Float;
	public var quality:StageQuality;
	public var stageFocusRect:Bool;
	public var scaleMode:StageScaleMode;
	public var stageHeight (default, null):Int;
	public var stageWidth (default, null):Int;
	
	private var __clearBeforeRender:Bool;
	private var __color:Int;
	private var __colorSplit:Array<Float>;
	private var __colorString:String;
	private var __cursor:String;
	private var __cursorHidden:Bool;
	private var __dirty:Bool;
	private var __dragBounds:Rectangle;
	private var __dragObject:Sprite;
	private var __dragOffsetX:Float;
	private var __dragOffsetY:Float;
	private var __focus:InteractiveObject;
	private var __fullscreen:Bool;
	private var __glProgram:ShaderProgram;
	//private var __glContextID:Int;
	//private var __glContextLost:Bool;
	//private var __glOptions:Dynamic;
	private var __invalidated:Bool;
	private var __mouseX:Float = 0;
	private var __mouseY:Float = 0;
	private var __originalWidth:Int;
	private var __originalHeight:Int;
	private var __renderSession:RenderSession;
	private var __stack:Array<DisplayObject>;
	private var __transparent:Bool;
	private var __wasDirty:Bool;
	
	#if js
	//private var __div:DivElement;
	//private var __element:HtmlElement;
	#if stats
	private var __stats:Dynamic;
	#end
	#end
	
	
	public function new (width:Int, height:Int, color:Null<Int> = null) {
		
		super ();
		
		if (color == null) {
			
			__transparent = true;
			this.color = 0x000000;
			
		} else {
			
			this.color = color;
			
		}
		
		this.name = null;
		
		__mouseX = 0;
		__mouseY = 0;
		
		__renderSession = new RenderSession ();
		__renderSession.roundPixels = true;
		
		#if js
		var prefix = untyped __js__ ("(function () {
		  var styles = window.getComputedStyle(document.documentElement, ''),
			pre = (Array.prototype.slice
			  .call(styles)
			  .join('') 
			  .match(/-(moz|webkit|ms)-/) || (styles.OLink === '' && ['', 'o'])
			)[1],
			dom = ('WebKit|Moz|MS|O').match(new RegExp('(' + pre + ')', 'i'))[1];
		  return {
			dom: dom,
			lowercase: pre,
			css: '-' + pre + '-',
			js: pre[0].toUpperCase() + pre.substr(1)
		  };
		})")();
		
		__renderSession.vendorPrefix = prefix.lowercase;
		__renderSession.transformProperty = (prefix.lowercase == "webkit") ? "-webkit-transform" : "transform";
		__renderSession.transformOriginProperty = (prefix.lowercase == "webkit") ? "-webkit-transform-origin" : "transform-origin";
		#end
		
		stageWidth = width;
		stageHeight = height;
		
		this.stage = this;
		
		align = StageAlign.TOP_LEFT;
		allowsFullScreen = false;
		displayState = StageDisplayState.NORMAL;
		frameRate = 60;
		quality = StageQuality.HIGH;
		scaleMode = StageScaleMode.NO_SCALE;
		stageFocusRect = true;
		
		__clearBeforeRender = true;
		__stack = [];
		
	}
	
	
	public override function globalToLocal (pos:Point):Point {
		
		return pos;
		
	}
	
	
	public function invalidate ():Void {
		
		__invalidated = true;
		
	}
	
	
	public override function localToGlobal (pos:Point):Point {
		
		return pos;
		
	}
	
	
	private function __drag (mouse:Point):Void {
		
		var parent = __dragObject.parent;
		if (parent != null) {
			
			mouse = parent.globalToLocal (mouse);
			
		}
		
		var x = mouse.x + __dragOffsetX;
		var y = mouse.y + __dragOffsetY;
		
		if (__dragBounds != null) {
			
			if (x < __dragBounds.x) {
				
				x = __dragBounds.x;
				
			} else if (x > __dragBounds.right) {
				
				x = __dragBounds.right;
				
			}
			
			if (y < __dragBounds.y) {
				
				y = __dragBounds.y;
				
			} else if (y > __dragBounds.bottom) {
				
				y = __dragBounds.bottom;
				
			}
			
		}
		
		__dragObject.x = x;
		__dragObject.y = y;
		
	}
	
	
	private function __fireEvent (event:Event, stack:Array<DisplayObject>):Void {
		
		var length = stack.length;
		
		if (length == 0) {
			
			event.eventPhase = EventPhase.AT_TARGET;
			event.target.__broadcast (event, false);
			
		} else {
			
			event.eventPhase = EventPhase.CAPTURING_PHASE;
			event.target = stack[stack.length - 1];
			
			for (i in 0...length - 1) {
				
				stack[i].__broadcast (event, false);
				
				if (event.__isCancelled) {
					
					return;
					
				}
				
			}
			
			event.eventPhase = EventPhase.AT_TARGET;
			event.target.__broadcast (event, false);
			
			if (event.__isCancelled) {
				
				return;
				
			}
			
			if (event.bubbles) {
				
				event.eventPhase = EventPhase.BUBBLING_PHASE;
				var i = length - 2;
				
				while (i >= 0) {
					
					stack[i].__broadcast (event, false);
					
					if (event.__isCancelled) {
						
						return;
						
					}
					
					i--;
					
				}
				
			}
			
		}
		
	}
	
	
	private override function __getInteractive (stack:Array<DisplayObject>):Void {
		
		stack.push (this);
		
	}
	
	
	private function __render (context:RenderContext):Void {
		
		__broadcast (new Event (Event.ENTER_FRAME), true);
		
		if (__invalidated) {
			
			__invalidated = false;
			__broadcast (new Event (Event.RENDER), true);
			
		}
		
		__renderable = true;
		__update (false, true);
		
		switch (context) {
			
			case OPENGL (gl):
				
				if (__glProgram == null) {
					
					__glProgram = new ShaderProgram ();
					__glProgram.compile ();
					
				}
				
				//if (!__glContextLost) {
					
					//__glContext.clear (color);
					//__glContext.setWindowSize (stageWidth, stageHeight);
					//__glContext.beginRender (null, false);
					
					/*gl.viewport (0, 0, stageWidth, stageHeight);
					gl.bindFramebuffer (gl.FRAMEBUFFER, null);
					
					if (__transparent) {
						
						gl.clearColor (1, 0, 0 ,0);
						
					} else {
						
						gl.clearColor (__colorSplit[0], __colorSplit[1], __colorSplit[2], 1);
						
					}
					
					gl.clear (gl.COLOR_BUFFER_BIT);*/
					
					if (__transparent) {
						
						gl.clearColor (1, 0, 0 ,0);
						
					} else {
						
						gl.clearColor (__colorSplit[0], __colorSplit[1], __colorSplit[2], 1);
						
					}
					
					gl.clear (gl.COLOR_BUFFER_BIT);
					gl.useProgram (__glProgram.program);
					
					gl.enableVertexAttribArray (__glProgram.vertexAttribute);
					gl.enableVertexAttribArray (__glProgram.textureAttribute);
					
					//var matrix = Matrix4.createOrtho (0, window.width, window.height, 0, -1000, 1000);
					var matrix = Matrix4.createOrtho (0, stageWidth, stageHeight, 0, -1000, 1000);
					gl.uniformMatrix4fv (__glProgram.projectionMatrixUniform, false, matrix);
					
					__renderSession.gl = gl;
					__renderSession.glProgram = __glProgram;
					__renderGL (__renderSession);
					
					//__glContext.endRender ();
					
				//}
			
			case CANVAS (context):
				
				context.setTransform (1, 0, 0, 1, 0, 0);
				context.globalAlpha = 1;
				
				if (!__transparent && __clearBeforeRender) {
					
					context.fillStyle = __colorString;
					context.fillRect (0, 0, stageWidth, stageHeight);
					
				} else if (__transparent && __clearBeforeRender) {
					
					context.clearRect (0, 0, stageWidth, stageHeight);
					
				}
				
				__renderSession.context = context;
				__renderCanvas (__renderSession);
			
			case DOM (element):
				
				__renderSession.z = 1;
				__renderSession.element = element;
				__renderDOM (__renderSession);
			
			default:
			
		}
		
	}
	
	
	private function __resize ():Void {
		
		/*
		if (__element != null && (__div == null || (__div != null && __fullscreen))) {
			
			if (__fullscreen) {
				
				stageWidth = __element.clientWidth;
				stageHeight = __element.clientHeight;
				
				if (__canvas != null) {
					
					if (__element != cast __canvas) {
						
						__canvas.width = stageWidth;
						__canvas.height = stageHeight;
						
					}
					
				} else {
					
					__div.style.width = stageWidth + "px";
					__div.style.height = stageHeight + "px";
					
				}
				
			} else {
				
				var scaleX = __element.clientWidth / __originalWidth;
				var scaleY = __element.clientHeight / __originalHeight;
				
				var currentRatio = scaleX / scaleY;
				var targetRatio = Math.min (scaleX, scaleY);
				
				if (__canvas != null) {
					
					if (__element != cast __canvas) {
						
						__canvas.style.width = __originalWidth * targetRatio + "px";
						__canvas.style.height = __originalHeight * targetRatio + "px";
						__canvas.style.marginLeft = ((__element.clientWidth - (__originalWidth * targetRatio)) / 2) + "px";
						__canvas.style.marginTop = ((__element.clientHeight - (__originalHeight * targetRatio)) / 2) + "px";
						
					}
					
				} else {
					
					__div.style.width = __originalWidth * targetRatio + "px";
					__div.style.height = __originalHeight * targetRatio + "px";
					__div.style.marginLeft = ((__element.clientWidth - (__originalWidth * targetRatio)) / 2) + "px";
					__div.style.marginTop = ((__element.clientHeight - (__originalHeight * targetRatio)) / 2) + "px";
					
				}
				
			}
			
		}*/
		
	}
	
	
	private function __setCursor (cursor:String):Void {
		
		if (__cursor != cursor) {
			
			__cursor = cursor;
			
			if (!__cursorHidden) {
				
				//var element = __canvas != null ? __canvas : __div;
				//element.style.cursor = cursor;
				
			}
			
		}
		
	}
	
	
	private function __setCursorHidden (value:Bool):Void {
		
		if (__cursorHidden != value) {
			
			__cursorHidden = value;
			
			//var element = __canvas != null ? __canvas : __div;
			//element.style.cursor = value ? "none" : __cursor;
			
		}
		
	}
	
	
	private function __startDrag (sprite:Sprite, lockCenter:Bool, bounds:Rectangle):Void {
		
		__dragBounds = (bounds == null) ? null : bounds.clone ();
		__dragObject = sprite;
		
		if (__dragObject != null) {
			
			if (lockCenter) {
				
				__dragOffsetX = -__dragObject.width / 2;
				__dragOffsetY = -__dragObject.height / 2;
				
			} else {
				
				var mouse = new Point (mouseX, mouseY);
				var parent = __dragObject.parent;
				
				if (parent != null) {
					
					mouse = parent.globalToLocal (mouse);
					
				}
				
				__dragOffsetX = __dragObject.x - mouse.x;
				__dragOffsetY = __dragObject.y - mouse.y;
				
			}
			
		}
		
	}
	
	
	private function __stopDrag (sprite:Sprite):Void {
		
		__dragBounds = null;
		__dragObject = null;
		
	}
	
	
	public override function __update (transformOnly:Bool, updateChildren:Bool):Void {
		
		if (transformOnly) {
			
			if (DisplayObject.__worldTransformDirty > 0) {
				
				super.__update (true, updateChildren);
				
				if (updateChildren) {
					
					DisplayObject.__worldTransformDirty = 0;
					__dirty = true;
					
				}
				
			}
			
		} else {
			
			if (DisplayObject.__worldTransformDirty > 0 || __dirty || DisplayObject.__worldRenderDirty > 0) {
				
				super.__update (false, updateChildren);
				
				if (updateChildren) {
					
					#if dom
					__wasDirty = true;
					#end
					
					DisplayObject.__worldTransformDirty = 0;
					DisplayObject.__worldRenderDirty = 0;
					__dirty = false;
					
				}
				
			} #if dom else if (__wasDirty) {
				
				// If we were dirty last time, we need at least one more
				// update in order to clear "changed" properties
				
				super.__update (false, updateChildren);
				
				if (updateChildren) {
					
					__wasDirty = false;
					
				}
				
			} #end
			
		}
		
	}
	
	
	
	
	// Get & Set Methods
	
	
	
	
	private override function get_mouseX ():Float {
		
		return __mouseX;
		
	}
	
	
	private override function get_mouseY ():Float {
		
		return __mouseY;
		
	}
	
	
	
	
	// Event Handlers
	
	
	
	
	#if js
	private function canvas_onContextLost (event:js.html.webgl.ContextEvent):Void {
		
		//__glContextLost = true;
		
	}
	
	
	private function canvas_onContextRestored (event:js.html.webgl.ContextEvent):Void {
		
		//__glContextLost = false;
		
	}
	#end
	
	
	#if js
	private function window_onResize (event:js.html.Event):Void {
		
		__resize ();
		
		var event = new Event (Event.RESIZE);
		__broadcast (event, false);
		
	}
	#end
	
	
	
	
	// Get & Set Methods
	
	
	
	
	private function get_color ():Int {
		
		return __color;
		
	}
	
	
	private function set_color (value:Int):Int {
		
		var r = (value & 0xFF0000) >>> 16;
		var g = (value & 0x00FF00) >>> 8;
		var b = (value & 0x0000FF);
		
		__colorSplit = [ r / 0xFF, g / 0xFF, b / 0xFF ];
		__colorString = "#" + StringTools.hex (value, 6);
		
		return __color = value;
		
	}
	
	
	private function get_focus ():InteractiveObject {
		
		return __focus;
		
	}
	
	
	private function set_focus (value:InteractiveObject):InteractiveObject {
		
		if (value != __focus) {
			
			if (__focus != null) {
				
				var event = new FocusEvent (FocusEvent.FOCUS_OUT, true, false, value, false, 0);
				__stack = [];
				__focus.__getInteractive (__stack);
				__stack.reverse ();
				__fireEvent (event, __stack);
				
			}
			
			if (value != null) {
				
				var event = new FocusEvent (FocusEvent.FOCUS_IN, true, false, __focus, false, 0);
				__stack = [];
				value.__getInteractive (__stack);
				__stack.reverse ();
				__fireEvent (event, __stack);
				
			}
			
			__focus = value;
			
		}
		
		return __focus;
		
	}


	function set_displayState (value:StageDisplayState):StageDisplayState {
		
		/*switch(value) {
			case NORMAL:
				var fs_exit_function = untyped __js__("function() {
			    if (document.exitFullscreen) {
			      document.exitFullscreen();
			    } else if (document.msExitFullscreen) {
			      document.msExitFullscreen();
			    } else if (document.mozCancelFullScreen) {
			      document.mozCancelFullScreen();
			    } else if (document.webkitExitFullscreen) {
			      document.webkitExitFullscreen();
			    }
				}");
				fs_exit_function();
			case FULL_SCREEN | FULL_SCREEN_INTERACTIVE:
				var fsfunction = untyped __js__("function(elem) {
					if (elem.requestFullscreen) elem.requestFullscreen();
					else if (elem.msRequestFullscreen) elem.msRequestFullscreen();
					else if (elem.mozRequestFullScreen) elem.mozRequestFullScreen();
					else if (elem.webkitRequestFullscreen) elem.webkitRequestFullscreen();
				}");
				fsfunction(__element);
			default:
		}
		displayState = value;*/
		return value;
	}
	
}


class RenderSession {
	
	
	public var context:CanvasRenderContext;
	public var element:DOMRenderContext;
	public var gl:GLRenderContext;
	public var glProgram:ShaderProgram;
	//public var mask:Bool;
	public var maskManager:MaskManager;
	//public var scaleMode:ScaleMode;
	public var roundPixels:Bool;
	public var transformProperty:String;
	public var transformOriginProperty:String;
	public var vendorPrefix:String;
	public var z:Int;
	//public var smoothProperty:Null<Bool> = null;
	
	
	public function new () {
		
		maskManager = new MaskManager (this);
		
	}
	
	
}


class MaskManager {
	
	
	private var renderSession:RenderSession;
	
	
	public function new (renderSession:RenderSession) {
		
		this.renderSession = renderSession;
		
	}
	
	
	public function pushMask (mask:IBitmapDrawable):Void {
		
		var context = renderSession.context;
		
		context.save ();
		
		//var cacheAlpha = mask.__worldAlpha;
		var transform = mask.__worldTransform;
		if (transform == null) transform = new Matrix ();
		
		context.setTransform (transform.a, transform.c, transform.b, transform.d, transform.tx, transform.ty);
		
		context.beginPath ();
		mask.__renderMask (renderSession);
		
		context.clip ();
		
		//mask.worldAlpha = cacheAlpha;
		
	}
	
	
	public function pushRect (rect:Rectangle, transform:Matrix):Void {
		
		var context = renderSession.context;
		context.save ();
		
		context.setTransform (transform.a, transform.c, transform.b, transform.d, transform.tx, transform.ty);
		
		context.beginPath ();
		context.rect (rect.x, rect.y, rect.width, rect.height);
		context.clip ();
		
	}
	
	
	public function popMask ():Void {
		
		renderSession.context.restore ();
		
	}
	
	
}


class ShaderProgram {
	
	
	public var fragmentSource:String;
	public var imageUniform:lime.graphics.GLUniformLocation;
	public var program:lime.graphics.GLProgram;
	public var projectionMatrixUniform:lime.graphics.GLUniformLocation;
	public var vertexAttribute:Int;
	public var vertexSource:String;
	public var textureAttribute:Int;
	public var valid:Bool;
	public var viewMatrixUniform:lime.graphics.GLUniformLocation;
	
	
	public function new (vertexSource:String = null, fragmentSource:String = null) {
		
		if (vertexSource == null) {
			
			this.vertexSource = 
				
				"attribute vec4 aVertexPosition;
				attribute vec2 aTexCoord;
				varying vec2 vTexCoord;
				
				uniform mat4 uProjectionMatrix;
				uniform mat4 uModelViewMatrix;
				
				void main ()
				{
					vTexCoord = aTexCoord;
					gl_Position = uProjectionMatrix * uModelViewMatrix * aVertexPosition;
				}";
			
		}
		
		if (fragmentSource == null) {
			
			this.fragmentSource = 
				
				#if !desktop
				"precision mediump float;" +
				#end
				"varying vec2 vTexCoord;
				uniform sampler2D uImage0;
				
				void main ()
				{
					gl_FragColor = texture2D (uImage0, vTexCoord);
				}";
			
		}
		
	}
	
	
	public function compile ():Void {
		
		program = GLUtils.createProgram (vertexSource, fragmentSource);
		
		vertexAttribute = lime.graphics.GL.getAttribLocation (program, "aVertexPosition");
		textureAttribute = lime.graphics.GL.getAttribLocation (program, "aTexCoord");
		
		viewMatrixUniform = lime.graphics.GL.getUniformLocation (program, "uModelViewMatrix");
		projectionMatrixUniform = lime.graphics.GL.getUniformLocation (program, "uProjectionMatrix");
		imageUniform = lime.graphics.GL.getUniformLocation (program, "uImage0");
		
		valid = true;
		
	}
	
	
}


#else
typedef Stage = flash.display.Stage;
#end