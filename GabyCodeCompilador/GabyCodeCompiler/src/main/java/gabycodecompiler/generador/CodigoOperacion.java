/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.generador;

/**
 *
 * @author facu
 */

public enum CodigoOperacion{
    
    PUSH_LITERAL,
    LOAD_VAR,
    STORE_VAR,
    OP_ADD,
    OP_SUB,
    OP_MUL,
    OP_DIV,
    OP_AND,
    OP_OR,
    OP_CMP_LT,
    OP_CMP_GT,
    OP_CMP_EQ,
    JUMP,
    JUMP_IF_FALSE,
    CALL_HOST,
    HALT
}