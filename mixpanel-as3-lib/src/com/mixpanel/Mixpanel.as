package com.mixpanel
{
	import com.mixpanel.Storage;
	import com.mixpanel.Util;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	
	/**
	 * Mixpanel AS3 API
	 * <p>Version 2.2.1</p>
	 */
	
	public class Mixpanel extends EventDispatcher
	{
		
		// PROPERTIES :
		private var _:Util;
		private var token:String;
		private var disableAllEvents:Boolean = false;
		private var disabledEvents:Array = [];
		/** @private */		
		internal var storage:Storage;
		/** @private */
		internal var config:Object;
		private var defaultConfig:Object = {
			crossSubdomainStorage: true,
			test: false
		};
		/** The callback called on request processed or request failed. This property can be set through the constructor, or by calling the <code>setCallback</code> method. */
		private var callback:Function;
		/** The request queue. An event is dispatched at each changes on the queue in case you would want to cache it. The queue is processed only if the connection state 
		 * is set to <code>true</code>. */
		private var requestQueue:Vector.<MixpanelRequestDescriptor>;
		/** Whether an internet connection is available or not. Set to true by default, which means the request will be sent directly. It's up to you to update this value
		 * by calling the <code>setConnectionStatus</code> method from the outside if your app has a connection checking system. */
		private var connectionAvailable:Boolean = true;
		/** Whether the request queue is currently processing or not. */
		private var isProcessing:Boolean = false;
		
		
		// CONSTRUCTOR :
		/**
		 * Create an instance of the Mixpanel library 
		 * 
		 * @param token your Mixpanel API token
		 * 
		 */		
		public function Mixpanel(token:String, pendingRequestQueue:Vector.<MixpanelRequestDescriptor> = null, callback:Function = null)
		{
			_ = new Util();
			token = token;
			var protocol:String = _.browserProtocol();
			
			config = _.extend({}, defaultConfig, {
				apiHost: protocol + '//api.mixpanel.com/',
				storageName: "mp_" + token,
				token: token
			});
			
			storage = new Storage(config);
			
			// generate a distinct_id at instance creation
			// the user should override this id with identify()
			// if they want to set their own id
			this.register_once({ 'distinct_id': _.UUID() }, "");
			
			this.callback = callback;
			this.requestQueue = pendingRequestQueue != null ? pendingRequestQueue : new Vector.<MixpanelRequestDescriptor>();
		}
		
		
		
		
		// METHODS :
		
		///////////////////
		// REQUEST QUEUE //
		///////////////////
		
		/**
		 * Enqueues the given request data as a MixpanelRequestDescriptor object, and tries to process the queue if an internet conection is available.
		 */
		private function enqueueRequest(endpoint:String, data:Object):Object {
			const descriptor:MixpanelRequestDescriptor = MixpanelRequestDescriptor.get(endpoint, _.truncate(data, 255));
			requestQueue.push(descriptor);
			
			dispatchEvent(new MixpanelRequestEvent(MixpanelRequestEvent.QUEUE_UPDATED, requestQueue));
			
			processQueue();
			return descriptor.data;
		}
		
		
		/**
		 * Process the request queue, one after another, as they were pushed into the queue. 
		 */
		private function processQueue():void {
			
			if(!connectionAvailable) return;
			if(requestQueue.length == 0) return;
			if(isProcessing) return;
			
			isProcessing = true;
			const descriptor:MixpanelRequestDescriptor = requestQueue[0];
			sendRequest(descriptor.endPoint, descriptor.data);
		}
		
		
		/**
		 * Creates a new request with the given data, and sends it.
		 */
		private function sendRequest(endpoint:String, data:Object):void {			
			var request:URLRequest = new URLRequest(config.apiHost + endpoint);
			request.method = URLRequestMethod.GET;
			var params:URLVariables = new URLVariables();
			
			var jsonData:String = _.jsonEncode(data),
				encodedData:String = _.base64Encode(jsonData);
			
			params = _.extend(params, {
				_: new Date().time.toString(),
				data: encodedData,
				ip: 1
			});
			if (config["test"]) { params["test"] = 1; }
			if (config["verbose"]) { params["verbose"] = 1; }
			if (config["request_method"]) { request.method = config["request_method"]; }
			
			request.data = params;
			
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE,
				function(e:Event):void {
					// Removes the request that has been processed.
					requestQueue.shift();
					dispatchEvent(new MixpanelRequestEvent(MixpanelRequestEvent.QUEUE_UPDATED, requestQueue));
					
					if(callback != null) {
						callback(loader.data);
					}
					isProcessing = false;
					processQueue();
				});
			loader.addEventListener(IOErrorEvent.IO_ERROR,
				function(e:IOErrorEvent):void {
					if ((callback != null) && config["verbose"]) {
						callback('{"status":0,"error":"' + e.text + '"}');
					} else if (callback != null) {
						callback(0);
					}
					isProcessing = false;
					processQueue();
				});
			
			loader.load(request);
		}
		
		
		/**
		 * Track an event.  This is the most important Mixpanel function and
		 * the one you will be using the most
		 *  
		 * @param event the name of the event
		 * @param args if the first arg in args is an object, it will be used
		 * as the properties object.  The last argument is a callback function.
		 * The callback and properties arguments are both optional.
		 * @return the data sent to the server
		 * 
		 */
		public function track(event:String, ...args):Object
		{
			var properties:Object = null;
			properties = args[0];
			

			properties = properties ? _.extend({}, properties) : {};

			if (!properties["token"]) { properties.token = config.token; }
			properties["mp_lib"] = "as3";

			properties = storage.safeMerge(properties);

			var data:Object = {
				"event": event,
				"properties": properties
			};
			
			var ret:Object = undefined;
			if (disableAllEvents || disabledEvents.indexOf(event) != -1) {
				if (callback != null && config['verbose']) {
					ret = callback('{"status":0, "error":"Tracking of this event is disabled."}');
				} else if (callback != null) {
					ret = callback(0);
				}
			} else {
				ret = enqueueRequest("track", data);
			}

			return ret;
		}
		
		/**
		 * Disable events on the Mixpanel object.  If passed no arguments,
	     * this function disables tracking of any event.  If passed an
	     * array of event names, those events will be disabled, but other
	     * events will continue to be tracked.
	     *
	     * <p>Note: this function doesn't stop regular mixpanel functions from
	     * firing such as register and name_tag.</p> 
		 *
		 * @param events A array of event names to disable 
		 */		
		public function disable(events:Array = null):void
		{
			if (events == null) {
				disableAllEvents = true;
			} else {
				disabledEvents = disabledEvents.concat(events);
			}
		}
		
		/**
  		 * Register a set of super properties, which are included with all
	     * events/funnels.  This will overwrite previous super property
	     * values.  It is mutable unlike register_once.
		 * 
		 * @param properties Associative array of properties to store about the user
		 */		
		public function register(properties:Object):void
		{
			storage.register(properties);			
		}
		
		/**
		 * Register a set of super properties only once.  This will not
		 * overwrite previous super property values, unlike register().
		 * It's basically immutable.
		 *  
		 * @param properties Associative array of properties to store about the user
		 * @param defaultValue Value to override if already set in super properties (ex: "False")
		 * 
		 */		
		public function register_once(properties:Object, defaultValue:* = null):void
		{
			storage.registerOnce(properties, defaultValue);
		}
		
		/**
		 * Delete a super property stored with the current user.
		 *  
		 * @param property the name of the super property to remove
		 * 
		 */		
		public function unregister(property:String):void
		{
			storage.unregister(property);
		}
		
		/**
		 * Delete all super properties stored for the current user.
		 * 
		 * <p><strong>THIS IS UNREVERSABLE!  Be careful.</strong></p>
		 * 
		 */		
		public function unregister_all():void
		{
			storage.unregister_all();
		}
		
		/**
		 * Get the value of a super property by the property name.
		 *  
		 * @param property the name of the super property to retrieve
		 * @return the value of the super property
		 * 
		 */
		public function get_property(property:String):*
		{
			return storage.get(property);
		}
		
		/**
		 * Get the unique ID assigned to the user. This ID is
		 * automatically assigned unless you specify your own via
		 * identify().
		 * 
		 * @return the current distinct_id
		 */
		public function get_distinct_id():String
		{
			return get_property('distinct_id') as String;
		}
		
		/**
		 * Identify a user with a unique id.  All subsequent
	     * actions caused by this user will be tied to this identity.  This
	     * property is used to track unique visitors.  If the method is
	     * never called, then unique visitors will be identified by a UUID
	     * generated the first time they visit the site.
		 * 
		 * @param uniqueID A string that uniquely identifies the user
		 * 
		 */		
		public function identify(uniqueID:String):void
		{
			storage.register({ "distinct_id": uniqueID });
		}
		
		/**
		 * Provide a string to recognize the user by.  The string passed to
	     * this method will appear in the Mixpanel Streams product rather
	     * than an automatically generated name.  Name tags do not have to
	     * be unique.
		 *  
		 * @param name A human readable name for the user
		 * 
		 */		
		public function name_tag(name:String):void
		{
			storage.register({ "mp_name_tag": name });
		} 
		
		/**
		 * Set properties on a user record
		 * 
		 * <p>Usage:</p>
		 * 
		 * <pre>
		 * 		mixpanel.people_set('gender', 'm');
		 * 
		 * 		mixpanel.people.set({
		 * 			'company': 'Acme',
		 * 			'plan': 'free'
		 * 		});
		 * 
		 * 		// properties can be strings, integers or dates
		 * </pre>
		 */
		public function people_set(...args):Object
		{			
			var $set:Object = {}, callback:Function = null;
			
			if (args[0] is String) {
				$set[args[0]] = args[1];
			} else {
				$set = args[0];
			}
			
			if (args[args.length-1] is Function) {
				callback = args[args.length-1];
			}
			
			$set = $set ? _.extend({}, $set) : {};
			
			var data:Object = {
				"$set": $set,
				"$token": config.token,
				"$distinct_id": storage.get("distinct_id")
			};
			
			return enqueueRequest("engage", data);
		}
		
		/**
		 * Increment/decrement properties on a user record
		 * 
		 * <p>Usage:</p>
		 * 
		 * <pre>
		 * 		mixpanel.people_increment('page_views', 1);
		 * 
		 * 		// or, for convienience, if you're just incrementing a counter by 1, you can
		 * 		// simply do
		 * 		mixpanel.people_increment('page_views');
		 * 
		 * 		// to decrement a counter, pass a negative number
		 * 		mixpanel.people.increment('credits_left', -1);
		 * 
		 * 		// like mixpanel.people_set(), you can increment multiple properties at once:
		 * 		mixpanel.people.increment({
		 * 			'counter1': '1',
		 * 			'counter2': '3'
		 * 		});
		 * </pre>
		 */
		public function people_increment(...args):Object
		{			
			var props:Object = {}, callback:Function = null;
			
			if (args[0] is String) {
				props[args[0]] = args[1];
			} else {
				props = args[0];
			}
			
			if (args[args.length-1] is Function) {
				callback = args[args.length-1];
			}
			
			var $add:Object = {};
			for (var key:String in props) {
				if (props[key] is Number) { $add[key] = props[key]; }
			}
			
			var data:Object = {
				"$add": $add,
				"$token": config.token,
				"$distinct_id": storage.get("distinct_id")
			};
			
			return enqueueRequest("engage", data);
		}
		
		/**
		 * Record that you have charged the current user a certain amount of money.
		 * 
		 * <p>Usage:</p>
		 * 
		 * <pre>
		 * 		// charge a user $29.99
		 * 		mixpanel.people_track_charge(29.99);
		 * 
		 * 		// charge a user $10 on the 2nd of January
		 * 	    // Note: $time must be a valid ISO datetime string
		 * 		mixpanel.people_track_charge(10, { '$time': '2012-01-02T00:00:00' });
		 * </pre>
		 */
		public function people_track_charge(amount:Number, ...args):Object
		{			
			var props:Object = {}, callback:Function = null;
			
			// get optional arguments
			if (args[0] is Object) { props = args[0]; } 
			if (args[args.length-1] is Function) { callback = args[args.length-1]; }
			
			props["$amount"] = amount;
			
			var data:Object = {
				"$append": { "$transactions": props },
				"$token": config.token,
				"$distinct_id": storage.get("distinct_id")
			};
			
			return enqueueRequest("engage", data);
		}
		
		/**
		 * Clear all the current user's transactions.
		 * 
		 * <p>Usage:</p>
		 * 
		 * <pre>
		 * 		mixpanel.people_clear_charges();
		 * </pre>
		 */
		public function people_clear_charges(...args):Object
		{			
			var callback:Function = null;
			if (args[args.length-1] is Function) { callback = args[args.length-1]; }
			
			var data:Object = {
				"$set": { "$transactions": [] },
				"$token": config.token,
				"$distinct_id": storage.get("distinct_id")
			};
			
			return enqueueRequest("engage", data);
		}
		
		/**
		 * delete the current user record (using current distinct_id)
		 * 
		 * <p>Usage:</p>
		 * 		
		 * <pre>
		 * 		mixpanel.people_delete();
		 * </pre>
		 */
		public function people_delete(...args):Object
		{			
			var callback:Function = null;
			if (args[0] is Function) {
				callback = args[0];
			}
			
			var data:Object = {
				"$delete": storage.get("distinct_id"),
				"$token": config.token,
				"$distinct_id": storage.get("distinct_id")
			};
			
			return enqueueRequest("engage", data);
		}

		/**
		 * Update the configuration of a mixpanel library instance.
		 * 
		 * <p>The default config is:</p>
		 * <pre>
		 * {
		 *     // super properties span subdomains
		 *     crossSubdomainStorage: true,
		 * 
		 *     // enable test in development mode
		 *     test: false,
		 *
		 * 	   // enable longer, debug-friendly api responses
		 *     verbose: false,
		 *
		 *     // Method to use when sending Mixpanel HTTP API requests,
		 *     // should be either URLRequestMethod.GET or URLRequestMethod.POST
		 *     request_method: URLRequestMethod.GET
		 * };
		 * </pre>
		 *
		 * @param config A dictionary of new configuration values to update
		 * 
		 */		
		public function set_config(config:Object):void
		{
			if (config["crossSubdomainStorage"] && config.crossSubdomainStorage != this.config.crossSubdomainStorage) {
				storage.updateCrossDomain(config.crossSubdomainStorage);
			}
			_.extend(this.config, config);
		}
		
		
		
		
		
		////////////
		// PARAMS //
		////////////
		
		/**
		 * Sets the given function as the callback used on a request response.
		 */
		public function setCallback(callback:Function):void {
			this.callback = callback;
		}
		
		/**
		 * Sets the given connection status as the current connection status. If set to false, the requests will not be sent, only enqueued.
		 * When set to true, it will process the request queue if it is not empty.
		 */
		public function setConnectionStatus(available:Boolean):void {
			if(connectionAvailable == available)
				return;
			
			this.connectionAvailable = available;
			processQueue();
		}
	}
}