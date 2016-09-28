/*
 *************************************************************************
 *
 *                   "DHRYSTONE" Benchmark Program
 *                   -----------------------------
 *
 *  Version:    C, Version 2.1
 *
 *  File:       dhry_1.c (part 2 of 3)
 *
 *  Date:       May 25, 1988
 *
 *  Author:     Reinhold P. Weicker
 *
 *************************************************************************
 */

/***************************************************************************
 * Adapted for embedded microcontrollers by Graham Davies, ECROS Technology.
 * Ported to SARATOGA softcore by Andrew Zonenberg, modified to use PC-side timing measurements.
 **************************************************************************/

#include "dhry.h"
//#include "stdlib.h"
#include "stdio.h"
#include "string.h"

#include <saratoga/saratoga.h>
#include <rpc.h>

/* Global Variables: */

Rec_Pointer     Ptr_Glob,
                Next_Ptr_Glob;
int             Int_Glob;
Boolean         Bool_Glob;
char            Ch_1_Glob,
                Ch_2_Glob;
int             Arr_1_Glob [25];        /* <-- changed from 50 */
int             Arr_2_Glob [25] [25];   /* <-- changed from 50 */

//Changed to global variable instead of malloc
Rec_Type rec1;
Rec_Type rec2;

void Proc_1( Rec_Pointer Ptr_Val_Par );
void Proc_2( One_Fifty * Int_Par_Ref );
void Proc_3( Rec_Pointer * Ptr_Ref_Par );
void Proc_4( void );
void Proc_5( void );

int main()
{
	One_Fifty       Int_1_Loc = 0;	//initialized to avoid false positive in cppcheck
	One_Fifty       Int_3_Loc;
	char            Ch_Index;
	Enumeration     Enum_Loc;
	Str_30          Str_1_Loc;
	Str_30          Str_2_Loc;
	int             Run_Index;

	Next_Ptr_Glob = &rec1;
	Ptr_Glob = &rec2;

	Ptr_Glob->Ptr_Comp                    = Next_Ptr_Glob;
	Ptr_Glob->Discr                       = Ident_1;
	Ptr_Glob->variant.var_1.Enum_Comp     = Ident_3;
	Ptr_Glob->variant.var_1.Int_Comp      = 40;
  
	strcpy (Ptr_Glob->variant.var_1.Str_Comp, 
		  "DHRYSTONE PROGRAM, SOME STRING");
	strcpy (Str_1_Loc, "DHRYSTONE PROGRAM, 1'ST STRING");

	Arr_2_Glob [8][7] = 10;
	/* Was missing in published program. Without this statement,    */
	/* Arr_2_Glob [8][7] would have an undefined value.             */
	/* Warning: With 16-Bit processors and Number_Of_Runs > 32000,  */
	/* overflow may occur for this array element.                   */
	
	//Get the initial config command
	//DEBUG: Drop anything from off chip. This is a quick hack to prevent RAM write-done interrupts from messing it up.
	RPCMessage_t rmsg;
	while(1)
	{
		RecvRPCMessage(&rmsg);
		if( (rmsg.from & 0xc000) == 0xc000 )
			break;
	}
	int Number_Of_Runs = rmsg.data[0];

	//Send back the ACK (this indicates the start of the benchmark loop)
	RPCMessage_t msg;
	msg.from = 0;
	msg.to = rmsg.from;
	msg.type = RPC_TYPE_INTERRUPT;
	msg.data[0] = rmsg.from;
	msg.data[1] = rmsg.data[1];
	msg.data[2] = 0;
	msg.callnum = 0;
	SendRPCMessage(&msg);

	One_Fifty       Int_2_Loc = 0;
	for (Run_Index = 1; Run_Index <= Number_Of_Runs;  ++Run_Index)
	{
		Proc_5();
		Proc_4();												/* Ch_1_Glob == 'A', Ch_2_Glob == 'B', Bool_Glob == true */
		Int_1_Loc = 2;
		Int_2_Loc = 3;
		strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 2'ND STRING");
		Enum_Loc = Ident_2;
		Bool_Glob = ! Func_2 (Str_1_Loc, Str_2_Loc);			/* Bool_Glob == 1 */
		
		while (Int_1_Loc < Int_2_Loc)  							/* loop body executed once */
		{
			Int_3_Loc = 5 * Int_1_Loc - Int_2_Loc;				/* Int_3_Loc == 7 */
			Proc_7 (Int_1_Loc, Int_2_Loc, &Int_3_Loc);			/* Int_3_Loc == 7 */
			Int_1_Loc += 1;
		}														/* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
		
		Proc_8 (Arr_1_Glob, Arr_2_Glob, Int_1_Loc, Int_3_Loc);	/* Int_Glob == 5 */

		Proc_1 (Ptr_Glob);
		for (Ch_Index = 'A'; Ch_Index <= Ch_2_Glob; ++Ch_Index)	/* loop body executed twice */
		{
			if (Enum_Loc == Func_1 (Ch_Index, 'C'))				/* then, not executed */
			{
				Proc_6 (Ident_1, &Enum_Loc);
				strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 3'RD STRING");
				Int_2_Loc = Run_Index;
				Int_Glob = Run_Index;
			}
		}														/* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
		
		Int_2_Loc = Int_2_Loc * Int_1_Loc;
		Int_1_Loc = Int_2_Loc / Int_3_Loc;
		Int_2_Loc = 7 * (Int_2_Loc - Int_3_Loc) - Int_1_Loc;	/* Int_1_Loc == 1, Int_2_Loc == 13, Int_3_Loc == 7 */		
		Proc_2 (&Int_1_Loc);									/* Int_1_Loc == 5 */
	}															/* loop "for Run_Index" */
  
	//Send back the "done" message
	msg.callnum = 1;
	msg.data[0] = 0;
	msg.data[1] = 1;
	msg.data[2] = 0;
	SendRPCMessage(&msg);

	//Get profiling info
	unsigned int profdata[8] = {0};
	//GetProfilingStats(profdata);
	
	//Send back the values to ensure they don't get optimized out
	msg.callnum = 2;
	msg.data[0] = Bool_Glob;							//should be 1
	msg.data[1] = Int_Glob;								//should be 5
	msg.data[2] = Ch_1_Glob;							//should be 0x41
	SendRPCMessage(&msg);
	msg.callnum = 3;
	msg.data[0] = Ch_2_Glob;							//should be 0x42
	msg.data[1] = Arr_1_Glob[8];						//should be 7
	msg.data[2] = Arr_2_Glob[8][7];						//should be Nruns + 10
	SendRPCMessage(&msg);
	msg.callnum = 4;
	msg.data[0] = Ptr_Glob->Discr;						//should be 0
	msg.data[1] = (unsigned int)Ptr_Glob->Ptr_Comp;		//implementation dependent
	msg.data[2] = Ptr_Glob->variant.var_1.Enum_Comp;	//should be 2
	SendRPCMessage(&msg);
	msg.callnum = 5;
	msg.data[0] = Ptr_Glob->variant.var_1.Int_Comp;			//should be 17
	msg.data[1] = Next_Ptr_Glob->Discr;						//should be 0
	msg.data[2] = Next_Ptr_Glob->variant.var_1.Enum_Comp;	//should be 1
	SendRPCMessage(&msg);
	msg.callnum = 6;
	msg.data[0] = Next_Ptr_Glob->variant.var_1.Int_Comp;	//should be 18
	msg.data[1] = Int_1_Loc;								//should be 5
	msg.data[2] = Int_2_Loc;								//should be 13
	SendRPCMessage(&msg);
	msg.callnum = 7;
	msg.data[0] = Int_3_Loc;								//should be 7
	msg.data[1] = Enum_Loc;									//should be 1
	msg.data[2] = 0;
	SendRPCMessage(&msg);
		
	//printf ("  Str_Comp:          %s\n", Ptr_Glob->variant.var_1.Str_Comp);
	//printf ("        should be:   DHRYSTONE PROGRAM, SOME STRING\n");
	//printf ("  Str_Comp:          %s\n", Next_Ptr_Glob->variant.var_1.Str_Comp);
	//printf ("        should be:   DHRYSTONE PROGRAM, SOME STRING\n");
	//printf ("Str_1_Loc:           %s\n", Str_1_Loc);
	//printf ("        should be:   DHRYSTONE PROGRAM, 1'ST STRING\n");
	//printf ("Str_2_Loc:           %s\n", Str_2_Loc);
	//printf ("        should be:   DHRYSTONE PROGRAM, 2'ND STRING\n");
	
	//Send back profiling stats
	for(int i=0; i<4; i++)
	{
		msg.callnum = i+8;
		msg.data[0] = 0;
		msg.data[1] = profdata[i*2];
		msg.data[2] = profdata[i*2 + 1];
		SendRPCMessage(&msg);
	}
	

	return 0;
}


void Proc_1( Rec_Pointer Ptr_Val_Par )
/******************/
    /* executed once */
{
  Rec_Pointer Next_Record = Ptr_Val_Par->Ptr_Comp;  
                                        /* == Ptr_Glob_Next */
  /* Local variable, initialized with Ptr_Val_Par->Ptr_Comp,    */
  /* corresponds to "rename" in Ada, "with" in Pascal           */
  
  structassign (*Ptr_Val_Par->Ptr_Comp, *Ptr_Glob);
  Ptr_Val_Par->variant.var_1.Int_Comp = 5;
  Next_Record->variant.var_1.Int_Comp 
        = Ptr_Val_Par->variant.var_1.Int_Comp;
  Next_Record->Ptr_Comp = Ptr_Val_Par->Ptr_Comp;
  Proc_3 (&Next_Record->Ptr_Comp);
    /* Ptr_Val_Par->Ptr_Comp->Ptr_Comp 
                        == Ptr_Glob->Ptr_Comp */
  if (Next_Record->Discr == Ident_1)
    /* then, executed */
  {
    Next_Record->variant.var_1.Int_Comp = 6;
    Proc_6 (Ptr_Val_Par->variant.var_1.Enum_Comp, 
           &Next_Record->variant.var_1.Enum_Comp);
    Next_Record->Ptr_Comp = Ptr_Glob->Ptr_Comp;
    Proc_7 (Next_Record->variant.var_1.Int_Comp, 10, 
           &Next_Record->variant.var_1.Int_Comp);
  }
  else /* not executed */
    structassign (*Ptr_Val_Par, *Ptr_Val_Par->Ptr_Comp);
} /* Proc_1 */


void Proc_2( One_Fifty * Int_Par_Ref )
/******************/
    /* executed once */
    /* *Int_Par_Ref == 1, becomes 4 */
{
  One_Fifty  Int_Loc;
  Enumeration   Enum_Loc;

  Int_Loc = *Int_Par_Ref + 10;
  do /* executed once */
    if (Ch_1_Glob == 'A')
      /* then, executed */
    {
      Int_Loc -= 1;
      *Int_Par_Ref = Int_Loc - Int_Glob;
      Enum_Loc = Ident_1;
    } /* if */
  while (Enum_Loc != Ident_1); /* true */
} /* Proc_2 */


void Proc_3( Rec_Pointer * Ptr_Ref_Par )
/******************/
    /* executed once */
    /* Ptr_Ref_Par becomes Ptr_Glob */
{
  if (Ptr_Glob != Null)
    /* then, executed */
    *Ptr_Ref_Par = Ptr_Glob->Ptr_Comp;
  Proc_7 (10, Int_Glob, &Ptr_Glob->variant.var_1.Int_Comp);
} /* Proc_3 */


void Proc_4( void ) /* without parameters */
/*******/
    /* executed once */
{
  Boolean Bool_Loc;

  Bool_Loc = Ch_1_Glob == 'A';
  Bool_Glob = Bool_Loc | Bool_Glob;
  Ch_2_Glob = 'B';
} /* Proc_4 */


void Proc_5( void ) /* without parameters */
/*******/
    /* executed once */
{
  Ch_1_Glob = 'A';
  Bool_Glob = false;
} /* Proc_5 */


        /* Procedure for the assignment of structures,          */
        /* if the C compiler doesn't support this feature       */
#ifdef  NOSTRUCTASSIGN
memcpy (d, s, l)
register char   *d;
register char   *s;
register int    l;
{
        while (l--) *d++ = *s++;
}
#endif
