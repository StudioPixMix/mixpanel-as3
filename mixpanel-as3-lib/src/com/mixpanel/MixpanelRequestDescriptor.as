package com.mixpanel {
	
	/**
	 *A simple object containing the data to create a new mixpanel request.
	 */
	public class MixpanelRequestDescriptor {
		
		// PROPERTIES :
		/** The endpoint to give to the request that will be created. */
		public var endPoint:String;
		/** The data to pass to the request. */
		public var data:Object;
		
		// CONSTRUCTOR :
		// Empty constructor
		public function MixpanelRequestDescriptor() {
			super();
		}
		
		
		// FACTORY :
		/**
		 * Returns a new instance of MixpanelRequestDescriptor filled with the given parameters.
		 */
		public static function get(endPoint:String, data:Object):MixpanelRequestDescriptor {
			var instance:MixpanelRequestDescriptor = new MixpanelRequestDescriptor();
			instance.endPoint = endPoint;
			instance.data = data;
			return instance;
		}
	}
}