//+------------------------------------------------------------------+
//|                                              LineNavigator.mq5 |
//|                                     Copyright 2023, Your Name |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name"
#property version   "1.00"

#property indicator_chart_window
#property indicator_plots 0

//--- Hotkeys for navigation (Left and Right Arrow Keys)
#define KEY_PREVIOUS 37 // Virtual-Key Code for Left Arrow
#define KEY_NEXT     39 // Virtual-Key Code for Right Arrow

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   Comment("Line Navigator Active\nUse <-- and --> to jump between lines.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit: Clean up when the indicator is removed                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0);
   Comment("");
  }
  
//+------------------------------------------------------------------+
//| OnCalculate (required for indicators, but we don't need it)      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| The brain of the indicator: handles chart events                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_KEYDOWN)
     {
      if(lparam != KEY_PREVIOUS && lparam != KEY_NEXT)
         return;

      // --- Gather all vertical lines and sort them ---
      datetime vline_times[];
      int vline_count = 0;
      for(int i = 0; i < ObjectsTotal(0); i++)
        {
         string obj_name = ObjectName(0, i);
         if(ObjectGetInteger(0, obj_name, OBJPROP_TYPE) == OBJ_VLINE)
           {
            ArrayResize(vline_times, vline_count + 1);
            vline_times[vline_count] = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME, 0);
            vline_count++;
           }
        }
        
      if(vline_count == 0) return;
      ArraySort(vline_times);
      
      // --- Find the line CLOSEST to the center of the screen ---
      long first_bar = ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
      long visible_bars = ChartGetInteger(0, CHART_VISIBLE_BARS);
      datetime center_time = iTime(NULL, 0, (int)(first_bar - visible_bars / 2));
      
      int current_line_index = -1;
      long min_diff = -1;

      for(int i = 0; i < vline_count; i++)
        {
         long diff = MathAbs( (long)vline_times[i] - (long)center_time );
         if(min_diff == -1 || diff < min_diff)
           {
            min_diff = diff;
            current_line_index = i;
           }
        }
      
      if(current_line_index == -1) return; // Should not happen if lines exist

      // --- Determine the TARGET index in our sorted list ---
      int target_line_index = 0;
      
      if(lparam == KEY_NEXT)
        {
         target_line_index = current_line_index + 1;
         // Wraparound logic
         if(target_line_index >= vline_count)
            target_line_index = 0;
        }
      else if(lparam == KEY_PREVIOUS)
        {
         target_line_index = current_line_index - 1;
         // Wraparound logic
         if(target_line_index < 0)
            target_line_index = vline_count - 1;
        }

      // --- Get the target time from our list ---
      datetime target_time = vline_times[target_line_index];

      // --- Execute the final, correct jump logic ---
      if(target_time > 0)
        {
         int target_shift = iBarShift(_Symbol, _Period, target_time);
         int rates_total = (int)SeriesInfoInteger(_Symbol, _Period, SERIES_BARS_COUNT);
         int target_shift_from_start = rates_total - 1 - target_shift;
         int new_left_shift = target_shift_from_start - (int)(visible_bars / 2);

         ChartNavigate(0, CHART_BEGIN, new_left_shift);
        }
     }
  }
//+------------------------------------------------------------------+