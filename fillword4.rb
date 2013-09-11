require 'rubygems'
require 'RMagick'

Face = RUBY_PLATFORM =~ /mswin/ ? 'Verdana': 'Times'

#單字類別
class CWord
	def initialize(word, canvasWidth, canvasHeight)
		@m_Word=word
		@m_CanvasWidth=canvasWidth
		@m_CanvasHeight=canvasHeight
	end
	
	attr_accessor :m_Word
	attr_accessor :m_Width
	attr_accessor :m_Height
	attr_accessor :m_Pixels
	attr_accessor :m_Left
	attr_accessor :m_Top
	attr_accessor :m_WordImg
	
	#產生單字影像
	def GenWordImg(size, color)
		@m_Size=size
		@m_Color=color
		@m_Canvas = Magick::Image.new(@m_CanvasWidth,@m_CanvasHeight,Magick::HatchFill.new('white'))
		m_Glyph = Magick::Draw.new
		m_Glyph.annotate(@m_Canvas, 0, 0, 0, 0, @m_Word) do
			m_Glyph.gravity=Magick::CenterGravity
			m_Glyph.pointsize = size
			m_Glyph.stroke = 'none'
			m_Glyph.fill = color
			m_Glyph.font_family = Face
			m_Glyph.font = 'times.ttf'
			m_Glyph.undercolor = '#ffffff'
		end
		pixels = @m_Canvas.get_pixels(0,0,@m_Canvas.columns,@m_Canvas.rows)
		cnt=0
		minX=9999
		minY=9999
		maxX=-1
		maxY=-1
		for pixel in pixels
			y=cnt/@m_Canvas.columns
			x=cnt%@m_Canvas.columns
			if(pixel.red!=255 or pixel.green!=255 or pixel.blue!=255)
				if(minX>x)
					minX=x
				end
				if(minY>y)
					minY=y
				end
				if(maxX<x)
					maxX=x
				end
				if(maxY<y)
					maxY=y
				end
			end
			cnt=cnt+1
		end
		@m_Left=minX
		@m_Top=minY
		@m_Width=maxX-minX+2
		@m_Height=maxY-minY+1
		@m_Pixels = @m_Canvas.get_pixels(@m_Left,@m_Top,@m_Width,@m_Height)	
		@m_WordImg = Magick::Image.new(@m_Width,@m_Height,Magick::HatchFill.new('white'))
		@m_WordImg.store_pixels(0,0,@m_WordImg.columns,@m_WordImg.rows,@m_Pixels)
	end
end

#畫布類別
class CCanvas
	def initialize(fileName)
		@m_File=fileName
		@m_Canvas = Magick::Image.read(fileName).first
		@m_DrawOK=0
	end
	attr_accessor :m_Canvas
	attr_accessor :m_DrawOK
	
	#找出可以填字的最大矩形區域
	def findMaxArea
		pixels = @m_Canvas.get_pixels(0,0,@m_Canvas.columns,@m_Canvas.rows)
		cnt=0
		minX=9999
		minY=9999
		maxX=-1
		maxY=-1
		for pixel in pixels
			y=cnt/@m_Canvas.columns
			x=cnt%@m_Canvas.columns
			if(pixel.red==255 and pixel.green==255 and pixel.blue==255)
				if(minX>x)
					minX=x
				end
				if(minY>y)
					minY=y
				end
				if(maxX<x)
					maxX=x
				end
				if(maxY<y)
					maxY=y
				end
			end
			cnt=cnt+1
		end
		@m_AreaLeft=minX
		@m_AreaTop=minY
		@m_AreaWidth=maxX-minX+1
		@m_AreaHeight=maxY-minY+1
	end
	
	#隨機找適合的位置填字
	def randomDraw(tryTimes, wordObject)
		find=0
		cnt=0
		@m_DrawOK=0
		while(find==0)
			posX=rand(@m_Canvas.columns-wordObject.m_Width)
			posY=rand(@m_Canvas.rows-wordObject.m_Height)
			pixels = @m_Canvas.get_pixels(posX,posY,wordObject.m_Width,wordObject.m_Height)
			occupied=0
			for pixel in pixels
				if(pixel.red!=255 or pixel.green!=255 or pixel.blue!=255)
					occupied=1
					break
				end
			end
			if(occupied==0)
				find=1
			else
				cnt=cnt+1
			end
			if(cnt>=tryTimes)
				break
			end
		end
		if(find==1)
			@m_Canvas.store_pixels(posX,posY, wordObject.m_Width, wordObject.m_Height, wordObject.m_Pixels)
			@m_DrawOK=1
		else
			puts "Random skip " + wordObject.m_Word
			@m_DrawOK=0
		end	
	end
	
	#輸出影像到檔案
	def outputImage(fileName)
		@m_Canvas.write(fileName)
	end
	
	#複製影像
	def copyPixels(destination)
		pixels=@m_Canvas.get_pixels(0,0,@m_Canvas.columns,@m_Canvas.rows)
		destination.store_pixels(0,0,@m_Canvas.columns,@m_Canvas.rows,pixels)	
	end
	
	#掃描可以填字的最大矩形區域找出適合的位置填字, 將影像縮小可以減少掃描的次數
	def scanDraw(ratio, wordObject) #ratio影像縮小比率
		pixels = @m_Canvas.get_pixels(@m_AreaLeft,@m_AreaTop,@m_AreaWidth,@m_AreaHeight)	
		areaImg = Magick::Image.new(@m_AreaWidth,@m_AreaHeight,Magick::HatchFill.new('white'))
		areaImg.store_pixels(0,0,areaImg.columns,areaImg.rows,pixels)	
		smallImg=areaImg.scale(areaImg.columns*ratio, areaImg.rows*ratio)
		wordImg=wordObject.m_WordImg.scale(wordObject.m_Width*ratio, wordObject.m_Height*ratio)
		
		@m_DrawOK=0
		find=0
		for i in (0..smallImg.rows-wordImg.rows-1)
			for j in (0..smallImg.columns-wordImg.columns-1)
				pixels=smallImg.get_pixels(j,i,wordImg.columns,wordImg.rows)
				occupied=0
				for pixel in pixels
					if(pixel.red!=255 or pixel.green!=255 or pixel.blue!=255)
						occupied=1
						break
					end
				end
				if(occupied==0)
					find=1
					break;
				end
			end
			if(find==1)
				break;
			end
		end
		if(find==1)
			locationX=@m_AreaLeft + j/ratio
			locationY=@m_AreaTop + i/ratio
			@m_Canvas.store_pixels(locationX, locationY, wordObject.m_Width, wordObject.m_Height, wordObject.m_Pixels)
			@m_DrawOK=1
		else
			puts "Scan skip " + wordObject.m_Word
			@m_DrawOK=0
		end
	end
end

#主程式
canvas=CCanvas.new("mask2.jpg") #讀取罩遮影像
canvas.findMaxArea() #找出可以填字的最大矩形區域
canvasResult=Magick::Image.new(canvas.m_Canvas.columns,canvas.m_Canvas.rows,Magick::HatchFill.new('white'))
canvas.copyPixels(canvasResult) #將初始影像複製到一暫存影像

#建立單字陣列	
wordArray=Array.new()
wordArray[0]='I'
wordArray[1]='Love'
wordArray[2]='You'
totalWord=3
wordObject=Array.new()
for i in (0..(totalWord-1))
	wordObject[i]=CWord.new(wordArray[i],canvas.m_Canvas.columns,canvas.m_Canvas.rows)
end
	
levelCnt=0 #計算繪圖迴圈跑幾次
fontSize=120 #初始最大字形尺寸
while(fontSize>=5) #繪圖迴圈結束條件
	puts "Font size " + fontSize.to_s
	for p in (0..levelCnt)
		if(levelCnt==0)
			color="#ff0000" #最大的字給紅色
		else #其他隨機
			color="##{"%02x" % (rand * 0xff) }#{"%02x" % (rand * 0xff) }#{"%02x" % (rand * 0xff) }" 
		end
		cnt=0
		for i in (0..(totalWord-1))
			wordObject[i].GenWordImg(fontSize,color) #產生單字影像
			canvas.randomDraw(100, wordObject[i]) #先用隨機填字
			if(canvas.m_DrawOK==0) #若沒找到地方填字
				canvas.scanDraw(0.4, wordObject[i]) #再用掃描填字
				if(canvas.m_DrawOK==1)
					cnt=cnt+1 #若成功時計數器加一
				else
					break #若失敗時此一尺寸的字都不用再試了
				end
			else
				cnt=cnt+1
			end
		end
		if(cnt==totalWord) #若計數器等於所有單字數, 表示此一尺寸的這一次繪圖所有單字都可以填入
			canvas.copyPixels(canvasResult) #將影像複製到站存影像
			canvasResult.write("result.jpg") #將影像輸出供觀察
		else #若計數器不等於所有單字數, 表示此一尺寸的這一次繪圖的某些單字無法填入, 將暫存影像複製回工作影像
			pixels=canvasResult.get_pixels(0,0,canvasResult.columns,canvasResult.rows)
			canvas.m_Canvas.store_pixels(0,0,canvasResult.columns,canvasResult.rows,pixels)
			puts "Skip font size " + fontSize.to_s
			break
		end
	end
	#每一繪圖迴圈的字體縮小規則
	if(levelCnt==0)
		fontSize=fontSize-fontSize/3
	else
		if(fontSize>=10)
			fontSize=fontSize-fontSize/10
		else
			fontSize=fontSize-1
		end
	end
	levelCnt=levelCnt+1
end
