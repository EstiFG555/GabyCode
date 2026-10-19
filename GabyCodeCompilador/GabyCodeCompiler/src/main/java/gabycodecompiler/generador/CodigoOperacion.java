/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.generador;

/**
 *
 * @author facu
 */

public enum CodigoOperacion {
    PUSH,
    POP,
    LOAD,
    STORE,
    ADD,
    SUB,
    MUL,
    DIV,
    AND,
    OR,
    LT,
    GT,
    EQ,
    JMP,
    JMP_IF_TRUE,
    JMP_IF_FALSE,
    CALL_HOST,
    PRINT,
    HALT
}