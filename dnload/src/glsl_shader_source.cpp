#include "glsl_shader_source.hpp"

#include <cstring>
#include <iostream>

#if defined(DNLOAD_GLESV2)
/** \cond */
#define GL_GLEXT_PROTOTYPES
/** \endcond */
#include "GLES2/gl2ext.h"
#endif


/** \brief Generate an indent.
 *
 * \param op Indent length.
 */
static std::string create_indent(unsigned op)
{
  std::ostringstream ret;

  for(unsigned ii = 0; (ii < op); ++ii)
  {
    ret << "  ";
  }
  return ret.str();
}

/** \brief Perform a set regex on a string.
 *
 * \param ii String iterator.
 * \return True if matches, false if not.
 */
static bool regex_space_plus_alpha_plus_semicolon(std::string::const_iterator ii,
    const std::string::const_iterator &ee)
{
  for(++ii; (ii != ee); ++ii)
  {
    if(' ' != *ii)
    {
      for(; (ii != ee); ++ii)
      {
        if(!isalpha(*ii))
        {
          for(; (ii != ee); ++ii)
          {
            char cc = *ii;

            if(' ' != cc)
            {
              return (';' == cc);
            }
          }
        }
      }
    }
  }
  return false;
}

GlslShaderSource::GlslShaderSource(const char *str1) :
    m_string(NULL),
    m_indent(0)
{
  this->add(str1);
}

GlslShaderSource::~GlslShaderSource()
{
  delete[] m_string;
}

void GlslShaderSource::add(const std::string &op)
{
  for(std::string::const_iterator ii = op.begin(), ee = op.end(); (ii != ee); ++ii)
  {		
    char cc = *ii;

    switch(cc)
    {
      case ';':
        m_source << ";\n" << create_indent(m_indent);
        break;

      case '{':
        m_source << std::endl << create_indent(m_indent) << "{\n";
        ++m_indent;
        m_source << create_indent(m_indent);
        break;

      case '}':
        --m_indent;
        m_source << '\r' << create_indent(m_indent) << "}";
        if(!regex_space_plus_alpha_plus_semicolon(ii + 1, ee) && (ii + 1 != ee))
        {
          m_source << std::endl << create_indent(m_indent);
        }
        break;

      default:
        m_source << cc;
        break;
    }
  }
}

const char* GlslShaderSource::c_str()
{
  std::string intermediate = m_source.str();
  size_t len = intermediate.length() + 1;

  delete[] m_string;
  m_string = new char[len];

  memcpy(m_string, intermediate.c_str(), len);

  return m_string;
}

std::string GlslShaderSource::get_pipeline_info_log(GLuint op)
{
#if defined(DNLOAD_GLESV2)
  (void)op;
  return std::string();
#else
  std::string ret;
  GLint len;

  glGetProgramPipelineiv(op, GL_INFO_LOG_LENGTH, &len);
  if(len)
  {
    GLchar *log = new GLchar[len];
    GLsizei acquired;

    glGetProgramPipelineInfoLog(op, len, &acquired, log);

    ret.assign(log);
    delete[] log;
  }

  return ret;
#endif
}

std::string GlslShaderSource::get_program_info_log(GLuint op)
{
  std::string ret;
  GLint len;

  std::cout << "Getting info log length." << std::endl;

  glGetProgramiv(op, GL_INFO_LOG_LENGTH, &len);
  std::cout << "len: " << len << std::endl;
  if(len)
  {
    GLchar *log = new GLchar[len];
    GLsizei acquired;

    glGetProgramInfoLog(op, len, &acquired, log);

    ret.assign(log);
    delete[] log;
  }

  return ret;
}

bool GlslShaderSource::get_program_link_status(GLuint op)
{
  GLint ret;

  glGetProgramiv(op, GL_LINK_STATUS, &ret);

  return (ret != 0);
}

bool GlslShaderSource::get_shader_compile_status(GLuint op)
{
  GLint ret;

  glGetShaderiv(op, GL_COMPILE_STATUS, &ret);

  return (ret != 0);
}

std::string GlslShaderSource::get_shader_info_log(GLuint op)
{
  std::string ret;
  GLint len;

  glGetShaderiv(op, GL_INFO_LOG_LENGTH, &len);
  if(len)
  {
    GLchar *log = new GLchar[len];
    GLsizei acquired;

    glGetShaderInfoLog(op, len, &acquired, log);

    ret.assign(log);
    delete[] log;
  }

  return ret;
}

