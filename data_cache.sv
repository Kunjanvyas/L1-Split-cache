typedef enum {invalid,shared,exclusive,modified} states;

module datacache (clk,rst,address,n);
input logic clk;
input logic rst;
parameter bitprocessor ='d32;
input logic [bitprocessor-1:0]address;
input logic [3:0] n;

parameter nway ='d8;
parameter logic mode =1'b1;
parameter sets = 'd 2**14;
parameter bytelines= 'd64;

localparam byte_offsetbits= $clog2(bytelines); 
localparam set_bits = $clog2(sets); 
localparam tag_bits= bitprocessor - set_bits - byte_offsetbits;
localparam lru_bits= $clog2(nway);

states cacheL1[sets-1:0][nway-1:0];
logic [lru_bits-1:0] lru[sets-1:0][nway-1:0];
logic [tag_bits-1:0]tag[sets-1:0][nway-1:0];
bit tagfirstwrite[sets-1:0][nway-1:0];
logic [bitprocessor-1:0] encoded_address ; 

int hit,miss,read,write,hitratio,stop;

logic [set_bits-1:0] indextest ; 
logic [tag_bits-1:0] tagtest ; 

assign indextest = address[bitprocessor-tag_bits-1:byte_offsetbits] ;
assign tagtest = address[bitprocessor-1:bitprocessor-tag_bits];
assign encoded_address = {tagtest,indextest,{byte_offsetbits{1'd0}}};

int hitptr,found,empty;

always_ff @(posedge clk ,posedge rst)
begin
if(rst)
	begin
	hit=0;
	miss=0;
	read=0;
	write=0;
	
	
	foreach(cacheL1[i,j])	
		begin
		if(cacheL1[i][j]==modified )
			begin
			$display("Return data to L2 %h",encoded_address); 
			cacheL1[i][j] <=invalid;
			lru[i][j]<= 3'b0;
			tagfirstwrite[i][j]<=1'b0;
			 tag[i][j]<=0;
			end
		else 
			begin
			lru[i][j]<= 3'b0;
			tagfirstwrite[i][j]<=1'b0;
			cacheL1[i][j] <=invalid;
			tag[i][j]<=0;
			end 
		end
	end

else
		
	begin
    unique case(n)
				
		0: 
		
			begin 
			for(int i=0;i<nway;i++)
				begin
				if(tag[indextest][i]==tagtest&&(cacheL1[indextest][i]!=invalid))
					begin
				                 
				    hitptr=i;
				    found=1;
										 
					end
				if(cacheL1[indextest][i]==invalid)
					begin
					
				    empty=1;
		
					end
				end
					
				if(found) 	
					begin
					
				    hit=hit+1;
					lruupdate(hitptr);
					
					end
				else		
				    begin
					for(int i=0;i<nway;i++)
						begin
						if(empty)
							begin
							if(cacheL1[indextest][i]==invalid&&stop==0)
								begin
								miss=miss+1;
								lruupdate(i);
								
								if(mode)
									$display("Read from L2 %h",encoded_address);
								cacheL1[indextest][i]<=exclusive;
								tag[indextest][i]<=tagtest;
								stop=1;
								end
								
							end
						else if(!empty) 
								begin
								if(lru[indextest][i]==3'b000&&stop==0)
									begin
									miss = miss+1 ;
									
									if(cacheL1[indextest][i]==modified)
										begin
										if(mode)
										$display("Write to L2 %h", encoded_address); 
										end 
											
									if(mode)
										$display("Read from L2 %h",encoded_address);
									lruupdate(i);
									cacheL1[indextest][i]<=exclusive;
									tag[indextest][i]<=tagtest;
									stop=1;
										
									end
								end
						end
					end	
			read=read+1;
			empty=0;
			found=0;
			stop=0;
			
			if(mode==1'b1)
			begin			
			for(int i=0;i<nway;i++)
				begin
				$display("--------------------------------");
				$display("::Coherency State and LRU Info::");
				$display("state => %p ",cacheL1[indextest][i]);
				$display("tag   => %h",tag[indextest][i]);
				$display("lru   => %d",lru[indextest][i]);
				$display("--------------------------------");
									
				end
			$display("--------------------------------");
			$display("read  => %d",read);
			$display("write => %d",write);
			$display("hit   => %d",hit);
			$display("miss  => %d",miss);
			$display("--------------------------------");
			end
	end
		1:
		
			begin
				for(int i=0;i<nway;i++)
			        begin
						if(tag[indextest][i]==tagtest&&(cacheL1[indextest][i]!=invalid))
									begin
						                   
										  hitptr=i;
										  found=1;
										 
									end
						if(cacheL1[indextest][i]==invalid)
									begin
									     empty=1;
									end
					end
										
							
						
					if(found)
						begin
							hit=hit+1;
							lruupdate(hitptr);
							cacheL1[indextest][hitptr] <= modified; 
							if(tagfirstwrite[indextest][hitptr]==0) //WRITE THROUGH IF FRIST WRITE
								begin
								if(mode==1'b1)
									begin
									$display("Write to L2 %h", encoded_address);
									cacheL1[indextest][hitptr] <= exclusive;
									end
								end
						found=0;
						tagfirstwrite[indextest][hitptr]=1;
						end

					else
					    begin
						for(int i=0;i<nway;i++)
						begin
							if(empty)
								begin
								if(cacheL1[indextest][i]==invalid&&stop==0)
									begin
									if(mode==1'b1)
									$display("Read for Ownership from L2 %h",encoded_address);
									miss=miss+1;
									lruupdate(i);
									cacheL1[indextest][i]<=modified;
									tag[indextest][i]<=tagtest;
									if(tagfirstwrite[indextest][i]==0)
											begin
											if(mode==1'b1)
											$display("Write to L2 %h", encoded_address);
											cacheL1[indextest][i]<=exclusive;
											end 
									tagfirstwrite[indextest][i]=1;
									stop=1;
									
									end
								end
							else if(empty==0)
							    begin
								if(lru[indextest][i]==3'b000&&stop==0)
									begin
										miss = miss+1 ;
										if(cacheL1[indextest][i]==modified && mode==1'b1)
											
											$display("Write to L2 %h",encoded_address);
											////////////
											if(mode==1'b1)
											$display("Read for ownership %h",encoded_address);
											lruupdate(i);
											cacheL1[indextest][i]<=modified;
											tag[indextest][i]<=tagtest;
											if(tagfirstwrite[indextest][i]==0)
											begin
											if(mode==1'b1)
											$display("Write to L2 %h",encoded_address);
											cacheL1[indextest][i]<=exclusive;
											end 
											tagfirstwrite[indextest][i]=1;
											stop=1;
											
											
											
									end
								end
						end
						end	
						write=write+1; 
						empty=0;
						found=0;
						stop=0;
						if(mode==1'b1)
						begin	
							for(int i=0;i<nway;i++)
						begin
									/*$display("state",cacheL1[indextest][i]);
									$display("tag=%h",tag[indextest][i]);
									$display("lru=%d",lru[indextest][i]);*/
									$display("--------------------------------");
				$display("::Coherency State and LRU Info::");
				$display("state => %p ",cacheL1[indextest][i]);
				$display("tag   => %h",tag[indextest][i]);
				$display("lru   => %d",lru[indextest][i]);
				$display("--------------------------------");
							
						end
									$display("--------------------------------");
									$display("read   => %d",read);
									$display("write  => %d",write);
									$display("hit    => %d",hit);
									$display("miss   => %d",miss);
									$display("--------------------------------");
					end
				end	

				
				
				
		3:   
			
			begin 
				for(int i=0;i<nway;i++)
					begin
					if(tag[indextest][i]==tagtest&&(cacheL1[indextest][i]!=invalid))
						begin
						if( cacheL1[indextest][i] == modified )
							begin 
							if(mode==1'b1)
								$display("write to L2 %h",encoded_address);  	//before other processor fetch data
							end 
									
						cacheL1[indextest][i]<= invalid;
						end
					end
			
			end		
		
		4:	 
				
			begin
				for(int i=0;i<nway;i++)
					begin
					if(tag[indextest][i]==tagtest&&(cacheL1[indextest][i]!=invalid))
						begin
							if(cacheL1[indextest][i]==modified)
								begin
								if(mode==1'b1)
									$display("Return data to L2  %h",encoded_address);  //for snoop as data is modified
								cacheL1[indextest][i]<= shared;
								end
								else if (cacheL1[indextest][i]==exclusive)
											cacheL1[indextest][i]<= shared ;
									 else 
										$display("WARNING : either data requested from a empty set or Tag didnot match ");
						end
					end		
			end
			
			
		9:	
			begin
			if(mode==1'b0)
			begin
			for(int i=0;i<nway;i++)
				begin
			    $display("--------------------------------");
				$display("::Coherency State and LRU Info::");
				$display("state => %p ",cacheL1[indextest][i]);
				$display("tag   => %h",tag[indextest][i]);
				$display("lru   => %d",lru[indextest][i]);
				$display("--------------------------------");
				/*$display("state",cacheL1[indextest][i]);
				$display("tag=%h",tag[indextest][i]);
				$display("lru=%d",lru[indextest][i]);*/
					
				end
			hitratio = (hit*100/(hit+miss)) ;
			$display("--------------------------------");
			$display("Stastics of Data Cache");
			$display("read       => %d",read);
			$display("write      => %d",write);
			$display("hit        => %d",hit);
			$display("miss       => %d",miss);
			$display("hit ratio  => %f",hitratio);
			$display("--------------------------------");
									 
			end
			end						
			
		8:	
		
			begin
			hit=0;
			miss=0;
			read=0;
			write=0;
			foreach(cacheL1[i,j])	
				begin	
				if(cacheL1[i][j]==modified )
					begin
					if(mode==1'b1)
					$display("Return data to L2 %h",encoded_address);
					cacheL1[i][j] <=invalid;
					lru[i][j]<= 3'b0;
					tagfirstwrite[i][j]<=1'b0;
					tag[i][j]<=0;
					end
				else 
					begin
					lru[i][j]<= 3'b0;
					tagfirstwrite[i][j]<=1'b0;
					cacheL1[i][j] <=invalid;
					tag[i][j]<=0;
					end 
				end
					
			
			end	
		default : ;
		endcase
	end
		
	end	


task lruupdate;
	input int i;
	begin
	for(int j=0;j<nway;j++)
		begin
		if( j!=i  ) 
			begin
			if(lru[indextest][j] > lru[indextest][i] )
				lru[indextest][j] <= lru[indextest][j]-3'b1 ;
			else 
				lru[indextest][j] <= lru[indextest][j];
			end
		end
		lru[indextest][i] <= 3'b111 ;
	end
endtask

endmodule
