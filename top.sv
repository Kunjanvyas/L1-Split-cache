typedef enum {invalid,shared,exclusive,modified} states;
module top();
parameter nway ='d8;
parameter sets = 'd 2**14;
parameter bytelines= 'd64;
parameter bitprocessor ='d32;
parameter mode = 0;
logic clk=0,reset=0;
logic [3:0] n;
logic [31:0] dataddr,instaddr;
logic [31:0] addr;
string filename;
int file;
string line;
int data;

datacache #(.mode(mode)) DUT (clk,reset,dataddr,n);
instructioncache #(.mode(mode)) DUT1 (.clk(clk),.rst(reset),.address(instaddr),.n(n));

initial
	forever #5 clk=~clk; 

initial
	begin
		reset=1;
		repeat(2)@(posedge clk);
		reset=0;
		repeat(1)@(posedge clk);
		file=$fopen("Trace.txt","r");
		if(file==1'b0)
		begin
			$display("File handle is empty");
			$finish;
		end
		while(!$feof(file))
			begin
			@(posedge clk)
				begin
				data=$fgets(line,file);
				//$display("         ");
				//$display("%s",line);
				if(data > 2) 
					begin 
					data=$sscanf(line,"%d %h",n,addr);
					end
				
				
				case(n)
				0:begin
					instaddr=addr;
					dataddr<=addr;
				  end
				1:begin
					instaddr=addr;
					dataddr<=addr;
				  end
				
				2:instaddr<=addr;
				
				3:begin
					instaddr=addr;
					dataddr<=addr;
				  end
				
				4:begin
					instaddr=addr;
					dataddr<=addr;
				  end
				8:begin 
					instaddr=addr;
					dataddr=addr;
				  end
				9:begin 
					instaddr=addr;
					dataddr<=addr;
				  end
				
				endcase
			end
		end			
	$fclose(file);
	if(mode==0) n=9;
	
	
	repeat (2) @(posedge clk) ;  
	$stop;			
		end
endmodule


