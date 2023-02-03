package ms.kenchen.Calculator;

import java.util.Date;

// Calculator Response
public class CalculatorResponse {
    int _x;
    int _y;
    int _result;
    String _time;
    String ip = "192.168.12.42";

    public CalculatorResponse(int x, int y, int result) {
        _x = x;
        _y = y;
        _result = result;
        _time = new Date().toString();
    }

    public int getX() { return _x; }

    public int getY() { return _y; }

    public int getNothing() { return 1; }

    public int getResult() { return _result; }

    public String getTime() { return _time; }

    private void login() {
        String username = "user";
        String password = "password";
    }

    private void sampleLoop() {
        int j;
        while (true) { // Noncompliant; end condition omitted
            j++;
        }
    }

    // Random Comment
}
