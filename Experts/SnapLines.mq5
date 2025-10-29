//+------------------------------------------------------------------+
//|                                                    SnapLines.mq5 |
//|                     Utility to snap lines to candle prices       |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property link      ""
#property version   "1.00"
#property description "Snaps Horizontal and Trend lines to the nearest O,H,L,C price after editing."

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Tell the chart to notify our EA when a user finishes editing an object.
   ChartSetInteger(0, CHART_PROP_EVENT_OBJECT_ENDEDIT, 1);
   Print("SnapLines EA Initialized. Waiting for you to draw or move a line.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clean up the chart property when the EA is removed.
   ChartSetInteger(0, CHART_PROP_EVENT_OBJECT_ENDEDIT, 0);
   Print("SnapLines EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Chart Event function - This is where all the logic happens       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- We only care about the event that fires AFTER an object is created or moved.
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      string object_name = sparam;
      ENUM_OBJECT object_type = (ENUM_OBJECT)ObjectGetInteger(0, object_name, OBJPROP_TYPE);
      
      Print("\n--- Object Edit Finished ---");
      Print("DEBUG: Object '", object_name, "' was just created or moved.");

      //--- We only want this to work for Horizontal Lines and Trendlines.
      if(object_type == OBJ_HLINE || object_type == OBJ_TREND)
      {
         Print("DEBUG: Object is a valid HLINE or TRENDLINE.");
         
         //--- We will snap the FIRST anchor point of the object.
         int point_index_to_snap = 0;
         
         //--- Get the final time and price of the anchor point the user placed.
         datetime final_time = (datetime)ObjectGetInteger(0, object_name, OBJPROP_TIME, point_index_to_snap);
         double final_price = ObjectGetDouble(0, object_name, OBJPROP_PRICE, point_index_to_snap);
         Print("DEBUG: User placed anchor point at Time=", (string)final_time, " Price=", final_price);
         
         //--- Find the bar index that corresponds to where the user dropped the line.
         int bar_index = iBarShift(_Symbol, _Period, final_time);

         if(bar_index >= 0)
         {
            Print("DEBUG: The closest bar is index #", bar_index);
            
            double candle_open  = iOpen(_Symbol, _Period, bar_index);
            double candle_high  = iHigh(_Symbol, _Period, bar_index);
            double candle_low   = iLow(_Symbol, _Period, bar_index);
            double candle_close = iClose(_Symbol, _Period, bar_index);
            
            double snap_prices[4];
            snap_prices[0] = candle_open;
            snap_prices[1] = candle_high;
            snap_prices[2] = candle_low;
            snap_prices[3] = candle_close;

            //--- Find which of the four prices is vertically closest to where the user dropped the line.
            double best_snap_price = 0;
            double min_distance = -1.0;
            for(int i = 0; i < 4; i++)
            {
               double distance = MathAbs(final_price - snap_prices[i]);
               if(min_distance < 0 || distance < min_distance)
               {
                  min_distance = distance;
                  best_snap_price = snap_prices[i];
               }
            }
            
            Print("DEBUG: Calculated best snap price as ", best_snap_price);
            
            //--- Move the anchor point's PRICE to the best snap price.
            ObjectSetDouble(0, object_name, OBJPROP_PRICE, point_index_to_snap, best_snap_price);
            
            // For a trendline used as a horizontal level, force both points to the same price.
            if(object_type == OBJ_TREND)
            {
                ObjectSetDouble(0, object_name, OBJPROP_PRICE, 1, best_snap_price);
            }

            ChartRedraw();
            Print("DEBUG: Snap complete. Object '",object_name,"' adjusted.");
         }
         else
         {
            Print("DEBUG: Could not find a bar at the specified time.");
         }
      }
      Print("--- Event Finished ---\n");
   }
}
//+------------------------------------------------------------------+