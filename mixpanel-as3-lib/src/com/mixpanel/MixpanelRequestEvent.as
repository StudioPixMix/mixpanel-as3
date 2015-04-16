package com.mixpanel {
	import flash.events.Event;
	
	
	/**
	 * An event dispatched on each change on the mixpanel request queue, which contains the updated value of this queue in case
	 * you would like to cache it on the outside, for apps which may run without an internet connection.
	 */
	public class MixpanelRequestEvent extends Event {
		
		// CONSTANTS :
		/** Dispatched when the request queue changed. */
		public static const QUEUE_UPDATED:String = "MixpanelRequestEvent.QueueUpdated";
		
		// PROPERTIES :
		/** The updated request queue of mixpanel events. */
		public var requestQueue:Vector.<MixpanelRequestDescriptor>;
		
		// CONSTRUCTOR :
		public function MixpanelRequestEvent(type:String, queue:Vector.<MixpanelRequestDescriptor>, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);
			this.requestQueue = queue;
		}
	}
}