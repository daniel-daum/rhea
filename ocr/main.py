from starlite import Starlite, post, Request, Response
from paddleocr import PaddleOCR
import base64
import io
from PIL import Image
import numpy as np

# Initialize PaddleOCR
ocr = PaddleOCR(use_angle_cls=True, lang='en')

@post("/ocr")
async def extract_text(request: Request) -> dict:
    """Extract text from uploaded image using PaddleOCR"""
    try:
        # Get JSON body
        body = await request.json()
        
        # Decode base64 image
        image_data = base64.b64decode(body['image'])
        image = Image.open(io.BytesIO(image_data))
        
        # Convert PIL image to numpy array
        img_array = np.array(image)
        
        # Run OCR
        result = ocr.ocr(img_array, cls=True)
        
        # Extract text from results
        extracted_text = []
        if result[0]:
            for line in result[0]:
                text = line[1][0]
                confidence = line[1][1]
                extracted_text.append({
                    "text": text,
                    "confidence": confidence
                })
        
        return {
            "success": True,
            "text": extracted_text,
            "full_text": " ".join([item["text"] for item in extracted_text])
        }
        
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

app = Starlite(route_handlers=[extract_text])

def main():
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

if __name__ == "__main__":
    main()