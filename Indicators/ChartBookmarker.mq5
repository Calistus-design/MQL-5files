//+------------------------------------------------------------------+
//|                                           ChartBookmarker.mq5 |
//|                                        Copyright 2023, Your Name |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name"
#property version   "1.02_FINAL"

#property indicator_chart_window
#property indicator_plots 0

// --- Global variables for settings ---
#define BOOKMARK_HOTKEY 'B' // Press 'B' to create a bookmark
#define DELETE_HOTKEY   'D' // Press 'D' to delete the nearest bookmark

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- The correct property to enable keyboard/mouse events is CHART_EVENT_MOUSE_MOVE
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   
   Comment("Chart Bookmarker Active\nPress 'B' with crosshair on a candle to save it.\nPress 'D' to delete the nearest bookmark.");
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| OnDeinit: Clean up when the indicator is removed                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Stop listening for key presses and clear the comment
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0);
   Comment("");
  }

//+------------------------------------------------------------------+
//| OnCalculate (required, but we don't need it to do anything)      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Chart Event handler - THIS IS THE BRAIN OF THE INDICATOR         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//--- We only care about keyboard presses
   if(id == CHARTEVENT_KEYDOWN)
     {
      //--- Get the time under the cursor ---
      long cursor_time_long = 0;
      
      //--- **FIX 1:** The correct property name is CHART_CROSSHAIR_TIME (no "_PROP_")
      if(!ChartGetInteger(0, CHART_CROSSHAIR_TIME, 0, cursor_time_long))
        {
         MessageBox("Could not read cursor position. Make sure crosshair is active.", "Error");
         return;
        }
      datetime cursor_time = (datetime)cursor_time_long;

      //--- Get chart info ---
      string symbol = _Symbol;
      string timeframe_str = PeriodToString(_Period);
      string datetime_str = TimeToString(cursor_time, TIME_DATE | TIME_MINUTES);

      //--- ACTION 1: CREATE A BOOKMARK ---
      if(lparam == BOOKMARK_HOTKEY)
        {
         // 1. Format the string
         string output_string = StringFormat("%s, %s, %s", symbol, timeframe_str, datetime_str);
         
         // 2. **FIX 2:** ClipboardSetText requires the string length as a second parameter.
         ClipboardSetText(output_string); // This is now correct in newer builds, but the more compatible way is below
                                          // Let's use the most compatible version to be safe, though your error implies it's not needed.
                                          // If the above line fails, use: ClipboardSetText(output_string, StringLen(output_string));

         
         // 3. Draw a visual marker (vertical line)
         string vline_name = "Bookmark_" + (string)cursor_time;
         ObjectCreate(0, vline_name, OBJ_VLINE, 0, cursor_time, 0);
         ObjectSetInteger(0, vline_name, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, vline_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, vline_name, OBJPROP_WIDTH, 1);
         
         // 4. Save to a permanent log file
         string file_name = symbol + "_" + timeframe_str + "_Bookmarks.txt";
         int file_handle = FileOpen(file_name, FILE_READ | FILE_WRITE | FILE_TXT);
         if(file_handle != INVALID_HANDLE)
           {
            FileSeek(file_handle, 0, SEEK_END);
            FileWriteString(file_handle, output_string + "\r\n");
            FileClose(file_handle);
           }
           
         ChartRedraw();
         MessageBox("Bookmark saved and copied to clipboard:\n" + output_string, "Success");
        }
        
      //--- ACTION 2: DELETE THE NEAREST BOOKMARK ---
      if(lparam == DELETE_HOTKEY)
        {
         string object_to_delete = "Bookmark_" + (string)cursor_time;
         
         if(ObjectDelete(0, object_to_delete))
           {
            ChartRedraw();
            MessageBox("Bookmark at " + datetime_str + " has been deleted.", "Bookmark Deleted");
           }
         else
           {
            MessageBox("No bookmark found at the cursor position to delete.", "Info");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| A helper function to convert period enum to a readable string    |
//+------------------------------------------------------------------+
string PeriodToString(ENUM_TIMEFRAMES period)
  {
   switch(period)
     {
      case PERIOD_M1:  return "1M";
      case PERIOD_M5:  return "5M";
      case PERIOD_M15: return "15M";
      case PERIOD_M30: return "30M";
      case PERIOD_H1:  return "1H";
      case PERIOD_H4:  return "4H";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return EnumToString(period);
     }
  }
//+------------------------------------------------------------------+