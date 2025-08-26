from SonicSurface import SonicSurface
import numpy as np

array = SonicSurface()
points = np.array( [ [-0.03,0.16,-0.03], [-0.03,0.16,0.03],[0.03,0.16,-0.03],[0.03,0.16,0.03] ] )
points = np.array( [ [-0.03,0.16,-0.03,1], [-0.03,0.16,0.03,0.5],[0.03,0.16,-0.03,0.25],[0.03,0.16,0.03,1] ] )

try:
    array.multiFocusIBP(points) #will give an error since it is not connected but phases will remain in array.ibpEmitters
except Exception as e:
    print(f"multiFocusIBP failed: {e}")

phases = np.angle(array.ibpEmitters).squeeze()
strPhases = "\n".join(str(phase) for phase in phases[:])
print(strPhases)