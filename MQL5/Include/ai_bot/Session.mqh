#property strict

#ifndef __AI_SESSION_MQH__
#define __AI_SESSION_MQH__

namespace AISession
  {
   bool IsWithinMYTWindow()
     {
      datetime utc=TimeGMT();
      datetime myt=utc+8*60*60;

      int dow=TimeDayOfWeek(myt);
      if(dow==0 || dow==6)
         return(false); // Skip Sunday and Saturday

      int minutes=TimeHour(myt)*60+TimeMinute(myt);
      int start=15*60; // 15:00 MYT
      int end=1*60;    // 01:00 MYT next day

      if(minutes>=start)
         return(true);
      if(minutes<end)
         return(true);
      return(false);
     }
  }
#endif
