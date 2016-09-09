#property description  "Name: tsEATest1.mq4"
#property description  "Idee: https://www.whselfinvest.de/en/trading_strategies_42_Break-out_Big_Candle.php"
#property description  ""
#property description  ""
#property description  ""

#property copyright "Thorsten Stratmann"
#property version   "101.101"
#property link "https://github.com/thorsten3003/mql4"



//---------- Allgemeine Einstellungen ----------
input int Magic = 101101;       // Magic number
input bool debug=false;
input bool AutoLots = True;     // if its True it will automatically calculate Lot based on Accont Balance.
input double MaximumRisk   =2;  // in Prozent
input double Lot = 0.1;         // feste Lotangabe wenn AutoLots=False
input int Slippage = 3;         // Orderausführung nur wenn Maximum price slippage kleiner ist
input int MaxOrders = 1;        // How many orders script can open on current symbol
input int MaxSpread = 18;       // If spread is above, orders will not be opened  
input bool OpenNurbeiNeuemBar=false; // Sollen nur Orders bei neuem Bar geöffnet werden?
int Ticket;                     // Variable für die aktuell ausgewählte Order
double spread;                  // MarketInfo(Symbol(),MODE_SPREAD);      Abstand des Haendlers zw. bid und ask
double Min_Dist;                // MarketInfo(Symbol(),MODE_STOPLEVEL);   Min. distance zw. bid/ask und SL bzw. TP
datetime prevtime;              // Hilft zur Erkennung ob ein neuer Bar angefangen hat
bool neuerBAR=true;             // Zeigt bei TRUE an das ein neuer Bar angefangen hat
double modspread;               //
int Nachkommastellen;           // Digits,   MarketInfo(Symbol(),MODE_DIGITS);
double SLPips;                  // Berechneter Abstand in Pips aus dem maximalen Risiko des Money Managements
double Lots;                    // Dieser Lotwert pro Order eingesetzt
double pp;                      // Points, MarketInfo(Symbol(),MODE_POINT);

// welcher Stop
input int welcherStop=1;            // 0=kein Stop; 1=Trailstop; 2=Bewegungsstop; 3=Trail- und Bewegungsstop, 4=Bewegungs und Trailstop

//-- Trailstop
input bool AllPositions  =False;  // AllPositions - use trailing stop for all opened positions
input bool ProfitTrailing=True;   // ProfitTrailing - trailing stop is activated as soon as the trade starts making profits, If "false" - trailing stop will be activated when new position is opened.
input int TrailingStop  =24;      // TrailingStop - fixed size of the trailing stop
input int TrailingStep  =10;      // TrailingStep - step of the trailing stop

//-- Bewegungsstop Markttechnik
input int barsInnenstaebe=20;   // Anzahl Bars zur Bestimmung ob Innenstaebe vorliegen
input bool InnenstaebeBeruecksichtigen=true; // Sollen die Innenstaebe bei buy/sell  beruecksichtigt werden

bool bar0=true;           // bei true wird erster SL auf Bar0 gelegt, sonst Bar1
double HighKurs=0.00;
double LowKurs=0.00;
int schleifenzaehler=0;  

//-- Bewegungsstop Markttechnik zur Innenstab berechnung
double einAustiegHochkurs;
double einAustiegTiefkurs;
bool Innenstab=false;
int NrAussenstab=0;

     
void OnTick() { // Executed when there is new tick.

   Nachkommastellen =MarketInfo(Symbol(),MODE_DIGITS);
   spread=MarketInfo(Symbol(),MODE_SPREAD);     // Abstand des Haendler zw. bid und ask
   Min_Dist =MarketInfo(Symbol(),MODE_STOPLEVEL);  //Min. distance zw. bid/ask und SL bzw. TP
   int AnzahlOrderOnSymbol=0;
   pp=MarketInfo(Symbol(),MODE_POINT);

//----------------------MoneyManagement --------------------------------

   if ( AutoLots == False ) 
     { 
       Lots = Lot; 
     }  
   else 
     { 
       Lots = MathRound ( AccountBalance() / 100 ) / 100; 
     } // First 100 say, that every 100$ will will increase lot by 1 point.
       // Second 100 say, that 1 point is equal to 0.01 lot
       // For ex. if you want to play 0.5 Lot with 1000$ account you can write MathRound ( AccountBalance() / 20 ) / 100;
  
   SLPips = ((AccountBalance() / 100 *MaximumRisk) * ( MarketInfo(Symbol(),MODE_TICKVALUE) *(1/Lots)))*Point*10;

  
  Comment( "LastTick=",TimeToStr(TimeCurrent(),TIME_SECONDS)," | Bar Opening=",TimeToStr(Time[0],TIME_SECONDS),"\n",
           "bid=",Bid, " | ", "ask=",Ask , "\n",
           "Spread= ", spread, "\n",
           "Nachkommastellen= ", Nachkommastellen, "\n",
           "Point= ", pp, "\n",
           "SLPips= ", SLPips, "\n",
           "Tickvalue= " , MarketInfo(Symbol(),MODE_TICKVALUE), "\n",
           "Ticksize= ", MarketInfo(Symbol(),MODE_TICKSIZE), "\n", 
           "Minlot= ", MarketInfo(Symbol(),MODE_MINLOT), "\n",
           "min.Dist bid/ask SL,TP=", Min_Dist
           );
    
   neuerBAR=isneuerBar();      // bestimmt ob neuer Bar beginnt            

   for ( int n = 0; n < OrdersTotal(); n++ ) {  // That loop search if there is opened order on current symbol.
      if ( OrderSelect ( n, SELECT_BY_POS ) ) {  
         if ( OrderSymbol() == Symbol() ) {  
            if ( OrderMagicNumber() == Magic ) {  
               Ticket = OrderTicket();  
               if ( OrderSelect ( Ticket, SELECT_BY_TICKET ) == True ) 
                  { 
                     close(); // If it found opened order, script jump to close() function which close orders and make trailing stops.
                  } 
               AnzahlOrderOnSymbol++;
            }
         }
      }
   }

   if ( AnzahlOrderOnSymbol < MaxOrders ) { open(); } // If MaxOrders are not reached it allow script to open one more order in order() function.
}

//---------------------------------------------------------------------------------

int open() {  

   double StopLoss;          //Stop loss level,    Ask - ( StopLoss * Point )
   double TakeProfit;        // Take profit level, Ask + ( TakeProfit * Point )
   string Kerzensignal="nix";
   string Kerzensignal2="nix";
   int ticket; 
   int upOrdown=0;

   //neuer Bar
   if(OpenNurbeiNeuemBar) {     // soll nur bei neuem Bar open erfolgen?
        if(neuerBAR==false)     // ist jetzt KEIN neuer BAR?
        {
                return(0);      // dann nix machen
        }
   }

// ---------------- Kerze 3 ...
   upOrdown = einAustiegKursBerechnen(2); //steigt oder fällt die 3. Kerze?
   // - The first candle in the pattern must be a "big" candle. Open price minus close price must be > than 1,75 x the 24-period ATR".
   double oc =einAustiegHochkurs-einAustiegTiefkurs;
   double grosseKerze = 1.75 * iATR(NULL,0,24,0);
   if(oc>grosseKerze)
        {
                if(upOrdown==1)  //steigende Kerze, BUY
                        {
                                Kerzensignal="BUY";
                        }
                else  if(upOrdown==2)  // fallende Kerze, SELL
                        {
                                Kerzensignal="SELL";
                        } 
        }     

        // ---------------- Kerze 2 ...
        upOrdown = einAustiegKursBerechnen(1); //steigt oder fällt die 2. Kerze?
        if (Kerzensignal=="BUY")
        {
          if(upOrdown==1)  //steigende Kerze2, BUY
                {
                if  ( High[1] > High[2])
                        {   
                                Kerzensignal2="BUY";
                        } 
                }              


          if(upOrdown==2)  // fallende Kerze2, SELL
                {
                if ( Low[1] < Low[2])
                        {   
                              Kerzensignal2="SELL";
                        } 
                }    
          }
   
// OpenOrder
if(Kerzensignal=="BUY" && Kerzensignal2=="BUY")
 {
     TakeProfit = NormalizeDouble(Ask + ( SLPips*pp),Digits);
     StopLoss = Ask-SLPips; 
   ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,Slippage,0,0,"My order",Magic,0,clrGreen);
   if(ticket<0)
     {
      Print("BUY OrderSend failed with error #",GetLastError());
      Print("Symbol:",Symbol()," OP_BUY"," Lots:",Lots,"Ask:",Ask," Slippage:",Slippage," StopLoss:",StopLoss);
     }
   else
      Print("BUY OrderSend placed successfully");
 }
 
 if(Kerzensignal=="SELL" && Kerzensignal2=="SELL")
 {
     TakeProfit = NormalizeDouble(Bid - ( SLPips*pp),Digits);
     StopLoss = Bid+SLPips; 
   ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,Slippage,0,0,"My order",Magic,0,clrGreen);
   if(ticket<0)
     {
      Print("SELL OrderSend failed with error #",GetLastError());
      Print("SLPips:",SLPips);
      Print("Symbol:",Symbol()," OP_SELL"," Lots:",Lots,"Bid:",Bid," Slippage:",Slippage," StopLoss:",StopLoss);
     }
   else
      Print("SELL OrderSend placed successfully");
 }
  
return ( 0 );
}

// ---------------------------------------------------------------------------------

int close() { // Close is executed when script find opened order on current symbol
  
   switch(welcherStop)         //0=kein Stop; 1=Trailstop; 2=Bewegungsstop; 3=Trail- und Bewegungsstop, 4=Bewegungs und Trailstop                
        {
        case 0 :    
        // kein Stop  
        break;          // Ende case 0: 
        case 1 :  
                trailingstop();
        break;          // Ende case 1: 
        case 2 :  
                bewegungsstop();
        break;          // Ende case 2:
        case 3 :  
                trailingstop();
                bewegungsstop();
        break;          // Ende case 3:
        case 4 :  
                bewegungsstop();
                trailingstop();
        break;          // Ende case 4:                
        } // End of switch


   return(0);
}
// ---------------------------------------------------------------------------------

void bewegungsstop() {
   bool Schleife=true;

   
      modspread=NormalizeDouble( (spread*Point),Digits);
      Min_Dist=NormalizeDouble( (Min_Dist*Point),Digits);
   


   if(Bars < barsInnenstaebe)                       // es werden soviele Bars muessen min. im Chart sein um die Innenstaebe zu bestimmen
     {
      Alert("Nicht genug Bars im Fenster.  Mindestens " + barsInnenstaebe + ". EA arbeitet nicht!");                                   // Exit start()
     }

   
   neuerBAR=isneuerBar();  // bestimmt ob neuer Bar beginnt

    
//------------------------------------------------------------------------------- 
    
            int Tip=OrderType();                   // Order type
            if(debug) Print("Verarbeite Order: " + Ticket + " - " +OrderTicket());      
            
            double SL    =OrderStopLoss();      // SL of the selected order
            double modifySL =0.00;              // das wird der neue SL
            double TP    =OrderTakeProfit();    // TP of the selected order
            double Price =OrderOpenPrice();     // Price of the selected order
            string Text="";           
            bool Modify=false;                  // Order wird bei true mofifiziert                          
 //---------------------------------------------------------------------- 3 --
                       
            switch(Tip)                         // By order type
              {
               case 0 :                         //  BUY Order
                  if(debug) Print("Case 0: BUY ORDER");
                  if( calcInnenstab() ) 
                  {  if(debug) Print("Innenstab vorhanden");
                     modifySL=NormalizeDouble(Low[NrAussenstab],Digits);     //SL auf Aussenstab (bid) setzen 
                     Text="SL der Buy Order auf Aussenstab Low="+ modifySL;        // Text for Buy 
                     Modify=true;      // To be modified
                  }
                  else if(bar0==true)
                        {  
                           bar0=false;       // ab dem zweiten Durchlauf Bar1 nehmen
                           modifySL=NormalizeDouble(Low[0],Digits);  //SL auf das Low (bid) von Bar0 setzen
                           Text="SL der Buy Order auf: bar0 Low="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }
                        else
                        {
                           modifySL=NormalizeDouble(Low[1],Digits);  //SL auf das Low (bid) von Bar1 setzen
                           Text="SL der Buy Order auf: bar1 Low="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }                      
            
            
               if (Bid - modifySL < Min_Dist)  // If less than allowed
                 { double test = Bid - modifySL;
                   Print("Bid:"+ Bid + "-modifySL:" + modifySL + "=" + test + "<Min_Dist:"+Min_Dist+"  Mindestabstand nicht erreicht. SL kann nicht geändert werden.");
                   Modify=false;
                 }
               
               break;      // Ende case 0: 

               case 1 :                // SELL ORDER
                  if(debug) Print("Case 1: SELL ORDER");
                  if( calcInnenstab() ) 
                  {
                     modifySL=NormalizeDouble( (High[NrAussenstab]+modspread),Digits);     //SL auf Aussenstab setzen (ask)
                     Text="SL der SELL Order anzupassen auf Aussenstab High="+ modifySL;        // Text for Buy 
                     Modify=true;      // To be modified
                  }
                  else if(bar0==true)
                        {
                           bar0=false;       // ab dem zweiten Durchlauf Bar1 nehmen
                           modifySL=NormalizeDouble( (High[0]+modspread),Digits);  //SL auf das High (ask) von Bar0 setzen
                           Text="SL der SELL Order auf: bar0 High="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }
                        else
                        {
                           modifySL=NormalizeDouble( (High[1]+modspread),Digits);  //SL auf das High (ask) von Bar1 setzen
                           Text="SL der SELL Order auf: bar1 High="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }   
                        
                if (modifySL - Ask < Min_Dist)  // If less than allowed
                 {  test = modifySL - Ask;
                   Print("Ask:"+ Ask + "-modifySL:" + modifySL + "=" + test + "<Min_Dist:"+Min_Dist+"  Mindestabstand nicht erreicht. SL kann nicht geändert werden.");
                   Modify=false;
                 }
                 
                                             
               } // End of switch
           
               Print("End Switch- akt.SL:"+SL + " , modifySL:"+modifySL+ " ,modspread:"+modspread );
               Print("Price:"+ Price);   

            //ist der SL gleich dem neuen SL? dann nicht aendern
            if(NormalizeDouble(SL,Digits)==NormalizeDouble(modifySL,Digits)) 
            {
               Modify=false;
            }
 //-------------------------------------------------------------------
            if (Modify==true)                 
               {              // Beginn Order verändern
                  schleifenzaehler=0;
                  while(Schleife==true)                            // Im Fehlerfall kann Order wiederholt werden
                 { 
                  schleifenzaehler++;
                  if(schleifenzaehler>=10) Schleife=false; // max. 10 Versuche

                  if(debug) Print ("Versuche ",Text,Ticket);
                  bool Ans=OrderModify(Ticket,Price,modifySL,TP,0);//Modify it!
   
//------------------------------------------------------------------- 6 --
                  if (Ans==true)                      // Order wurde geaendert
                    {
                     if(debug) Print("Order ",Ticket," wurde erfolgreich geaendert.)");
                     break;                           // while Schleife verlassen
                    }
                  //------------------------------------------------------------------- 7 --
                  int Error=GetLastError();           // Failed :(
                  switch(Error)                       // Overcomable errors
                    {
                     case 130:Print("Falsche Stops");
                        break;                     
                     case 136:Print("No prices. Waiting for a new tick..");
                        while(RefreshRates()==false)  // To the new tick
                           Sleep(1);                  // Cycle delay
                        continue;                     // At the next iteration
                     case 146:Print("Trading subsystem is busy. Retrying ");
                        Sleep(500);                   // Simple solution
                        RefreshRates();               // Update data
                        continue;                     // At the next iteration
                        // Critical errors
                     case 2 : Print("Common error.");
                        break;                        // Exit 'switch'
                     case 5 : Print("Old version of the client terminal.");
                        break;                        // Exit 'switch'
                     case 64: Print("Account is blocked.");
                        break;                        // Exit 'switch'
                     case 133:Print("Trading is prohibited");
                        break;                        // Exit 'switch'
                     default: Print("Occurred error ",Error);//Other errors
                    }
                  break;                              // From modification cycle
                 }                                    // End of modification cycle
            }                                         // Ende if(Modify==true)                                
   }    // Ende start
  



bool calcInnenstab()
{
   for(int i=barsInnenstaebe; i>=2; i--)          
      {
         Innenstab=true;
         NrAussenstab=0;
         int k=i;
      if(debug) Print("forloop- i="+i);
            while(Innenstab==true) 
            {
               k--;
               if(debug) Print("whileloop - k="+k);
               einAustiegKursBerechnen(k);
               
               if( (High[i] >= einAustiegHochkurs) && 
                   (Low[i]  <= einAustiegTiefkurs )  )
               {
                  Innenstab=true;
                  NrAussenstab=i;
                  if(debug) Print("Innenstab=JA");
               }
               else
               {
                  Innenstab=false;
                  NrAussenstab=0;
                  if(debug) Print("Innenstab=NEIN");
               }
            if(k==1) break;      //Wenn Innenstaebe bis zum Ende vorhanden dann while beenden
            }     // end while
      if(k==1) break;            //Wenn Innenstaebe bis zum Ende vorhanden dann auch forloop beenden
      }           // end for
      if(debug) Print("Innenstab="+Innenstab+ " NrAussenstab="+NrAussenstab);
   if( ! InnenstaebeBeruecksichtigen){ Innenstab=false;}
   return(Innenstab);
}

int einAustiegKursBerechnen(int k)
{
   int upOrdown=0; // steigende Kerze=1, fallende Kerze=2
   if(Open[k]>=Close[k])
      {
         einAustiegHochkurs = Open[k];
         einAustiegTiefkurs = Close[k];
         upOrdown=2;  // fallende Kerze
      }
   else
      {
         einAustiegHochkurs = Close[k];
         einAustiegTiefkurs = Open[k];
         upOrdown=1;  // steigende Kerze
      }
if(debug) Print("einAustiegHochkurs="+einAustiegHochkurs+" einAustiegTiefkurs="+einAustiegTiefkurs);
return(upOrdown);
}


// ---------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------
void trailingstop()
{
double pBid, pAsk;
//----

     if (OrderType()==OP_BUY) 
     {
      pBid=MarketInfo(OrderSymbol(), MODE_BID);
        if (!ProfitTrailing || (pBid-OrderOpenPrice())>TrailingStop*pp) 
        {
           if (OrderStopLoss()<pBid-(TrailingStop+TrailingStep-1)*pp) 
           {
            ModifyStopLoss(pBid-TrailingStop*pp);
            return;
           }
        }
     }
     if (OrderType()==OP_SELL) 
     {
      pAsk=MarketInfo(OrderSymbol(), MODE_ASK);
        if (!ProfitTrailing || OrderOpenPrice()-pAsk>TrailingStop*pp) 
        {
           if (OrderStopLoss()>pAsk+(TrailingStop+TrailingStep-1)*pp || OrderStopLoss()==0) 
           {
            ModifyStopLoss(pAsk+TrailingStop*pp);
            return;
           }
        }
     }
  }

  void ModifyStopLoss(double ldStopLoss) 
  {
   bool fm;
   fm=OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE);
  }



  //---------------- Tools


bool isneuerBar() {
   if(prevtime==Time[0])           
     {
        neuerBAR=false;
     }
     else
     {
       prevtime=Time[0];
       neuerBAR=true;
     }     
if(debug) Print("Neuer Bar um "+ TimeToStr(Time[0],TIME_SECONDS));   
return(neuerBAR); 
}


