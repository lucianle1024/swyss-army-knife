// math for manual collision detection

bool CheckCollisionCircles(float x1, float y1, float r1, float x2, float y2, float r2) {
    float dx = x2 - x1;
    float dy = y2 - y1;
    float distSq = dx * dx + dy * dy;
    float radSum = r1 + r2;

    return distSq < radSum * radSum;
}