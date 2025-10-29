//+------------------------------------------------------------------+
//|                                        ImportVerticalLines.mq5 |
//|                                     Copyright 2023, Your Name |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name"
#property version   "1.00"
#property description "Reads a text file to restore vertical lines onto the chart."

//+------------------------------------------------------------------+
//| The main function where the script's logic begins.               |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- STEP 1: INITIALIZATION ---

   // Get the chart's identity to find the correct blueprint file
   string symbol = _Symbol;
   string timeframe_str = PeriodToString(_Period);
   
   // Construct the exact filename we need to find
   string file_name = symbol + "_" + timeframe_str + "_Vertical_Lines.txt";
   
   // Open the file in 'read' mode
   int file_handle = FileOpen(file_name, FILE_READ | FILE_TXT);
   
   // Check if the file exists and was opened successfully
   if(file_handle == INVALID_HANDLE)
     {
      MessageBox("The required data file was not found.\n\nPlease ensure '" + file_name + "' is in the MQL5\\Files folder.", "File Not Found");
      return; // Stop the script if there's no file to read
     }

//--- STEP 2: THE CORE LOOP ---

   // Counters to track the process
   int lines_read = 0;
   int lines_created = 0;

   // Loop through the file until we reach the end
   while(!FileIsEnding(file_handle))
     {
      // Read one line of text from the file (e.g., "2025.09.20 14:00")
      string time_str = FileReadString(file_handle);
      
      // If the line is empty, skip it and continue
      if(StringLen(time_str) < 10)
         continue;
      
      // Convert the text string into a proper MQL5 datetime format
      datetime line_time = StringToTime(time_str);
      
      // We will create objects with a specific name to easily check for duplicates
      string object_name = "Imported_VLine_" + (string)line_time;
      
      // Check if a line with this exact name already exists on the chart
      if(ObjectFind(0, object_name) == -1) // -1 means "not found"
        {
         // The line does not exist, so let's create it
         ObjectCreate(0, object_name, OBJ_VLINE, 0, line_time, 0);
         
         // Set some visual properties for the newly created line
         ObjectSetInteger(0, object_name, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetInteger(0, object_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, object_name, OBJPROP_WIDTH, 1);
         
         // Increment the counter for newly created lines
         lines_created++;
        }
      
      lines_read++;
     }

//--- STEP 3: FINALIZATION ---

   // Close the file handle
   FileClose(file_handle);
   
   // Force the chart to redraw itself to make sure all new lines are visible
   ChartRedraw();
   
   // Prepare the final confirmation message
   string final_message = StringFormat("Import Complete.\n\nRead %d timestamps from the file.\nCreated %d new vertical lines on the chart.", lines_read, lines_created);
   
   // Display the message box
   MessageBox(final_message, "Import Successful");
  }

//+------------------------------------------------------------------+
//| A helper function to convert the timeframe into a readable string|
//+------------------------------------------------------------------+
string PeriodToString(ENUM_TIMEFRAMES period)
  {
   switch(period)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return EnumToString(period);
     }
  }
//+------------------------------------------------------------------+